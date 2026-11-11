#include "bench/common/options.hpp"
#include "bench/common/timing.cuh"
#include "bench/common/nvtx.hpp"
#include <iostream>
#include <map>

using namespace measure;
namespace {
constexpr size_t MiB = size_t(1) << 20;
struct LaunchConfig { int blocks_per_sm = 1, threads = 256; };
struct Peak { double bandwidth = 0; LaunchConfig launch; };
void launch_memory(const std::string& kind, const double2* source, double2* dest, size_t count,
                   double2* sink, int sms, LaunchConfig launch, cudaStream_t stream, int passes = 1) {
    const int blocks = sms * launch.blocks_per_sm;
    if (kind == "read") read16<<<blocks, launch.threads, 0, stream>>>(source, count, sink, passes);
    else if (kind == "write") write16<<<blocks, launch.threads, 0, stream>>>(dest, count, 1.0);
    else if (kind == "copy") copy16<<<blocks, launch.threads, 0, stream>>>(source, dest, count, passes);
    else if (kind == "cudaMemcpyD2D") T1_CUDA(cudaMemcpyAsync(dest, source, count * 16, cudaMemcpyDeviceToDevice, stream));
    else throw std::runtime_error("unknown memory kernel");
    T1_CUDA(cudaGetLastError());
}
std::map<std::string, Peak> hbm(const std::filesystem::path& root, size_t bytes, cudaStream_t stream, int sms) {
    DeviceBuffer<double2> source(bytes / 16), dest(bytes / 16), sink(size_t(sms) * 8);
    T1_CUDA(cudaMemsetAsync(source.get(), 0, bytes, stream));
    T1_CUDA(cudaMemsetAsync(dest.get(), 0, bytes, stream));
    auto out = new_output(root / "bandwidth/hbm.csv");
    out << "kernel,buffer_bytes,traffic_bytes,blocks_per_sm,threads,iterations,total_ms,time_ms,GBs,is_best\n";
    struct Row { std::string kind; LaunchConfig config; LongTiming time; double bw; };
    std::vector<Row> rows;
    std::map<std::string, Peak> peaks;
    for (const std::string kind : {"read", "write", "copy", "cudaMemcpyD2D"}) {
        const size_t traffic = bytes * ((kind == "copy" || kind == "cudaMemcpyD2D") ? 2 : 1);
        for (int bpsm : {1, 2, 4, 8}) for (int threads : {128, 256, 512}) {
            if (kind == "cudaMemcpyD2D" && (bpsm != 1 || threads != 128)) continue;
            const LaunchConfig config{bpsm, threads};
            auto execute = [&](cudaStream_t s) { launch_memory(kind, source.get(), dest.get(), bytes / 16, sink.get(), sms, config, s); };
            const auto timing = time_at_least(execute, stream);
            const double bandwidth = double(traffic) / timing.per_iteration_ms / 1e6;
            rows.push_back({kind, config, timing, bandwidth});
            if (bandwidth > peaks[kind].bandwidth) peaks[kind] = {bandwidth, config};
        }
    }
    for (const auto& row : rows) {
        const auto best = peaks.at(row.kind);
        out << row.kind << ',' << bytes << ',' << bytes * ((row.kind == "copy" || row.kind == "cudaMemcpyD2D") ? 2 : 1)
            << ',' << row.config.blocks_per_sm << ',' << row.config.threads << ',' << row.time.iterations
            << ',' << row.time.total_ms << ',' << row.time.per_iteration_ms << ',' << row.bw << ','
            << (row.config.blocks_per_sm == best.launch.blocks_per_sm && row.config.threads == best.launch.threads ? 1 : 0) << '\n';
    }
    for (const auto& item : peaks)
        std::cout << "HBM " << item.first << ": " << item.second.bandwidth << " GB/s; blocks/SM="
                  << item.second.launch.blocks_per_sm << " threads=" << item.second.launch.threads << '\n';
    return peaks;
}
void l2_and_limits(const std::filesystem::path& root, const std::map<std::string, Peak>& peaks,
                   cudaStream_t stream, int sms) {
    const size_t l2 = l2_bytes();
    auto out = new_output(root / "bandwidth/l2_curve.csv");
    out << "kernel,working_set_MiB,buffer_bytes,traffic_bytes,blocks_per_sm,threads,iterations,passes_per_launch,total_ms,time_ms,GBs,in_plateau\n";
    const std::vector<int> sizes = {1, 2, 4, 8, 16, 20, 24, 32, 40, 48, 64, 96, 128, 256, 512};
    std::map<std::string, std::vector<double>> plateau;
    std::vector<double> plateau_sizes;
    for (int mib : sizes) {
        const size_t working_set = size_t(mib) * MiB;
        const bool inside = working_set >= 4 * MiB && working_set <= l2 / 2;
        if (inside) plateau_sizes.push_back(mib);
        for (const std::string kind : {"read", "copy"}) {
            // Working set means the sum of distinct buffers touched. A copy has
            // two buffers of half this size, so its L2 transition is comparable.
            const size_t buffer_bytes = working_set / (kind == "copy" ? 2 : 1);
            DeviceBuffer<double2> source(buffer_bytes / 16), dest(kind == "copy" ? buffer_bytes / 16 : 0);
            DeviceBuffer<double2> sink(size_t(sms) * 8);
            T1_CUDA(cudaMemsetAsync(source.get(), 0, buffer_bytes, stream));
            if (dest.get()) T1_CUDA(cudaMemsetAsync(dest.get(), 0, buffer_bytes, stream));
            auto config = peaks.at(kind).launch;
            // Keep the entire grid resident. Oversubscribed blocks repeating
            // their private slices could make an oversized working set appear
            // resident in L2 one launch wave at a time.
            int resident = 0;
            if (kind == "read") T1_CUDA(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&resident, read16, config.threads, 0));
            else T1_CUDA(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&resident, copy16, config.threads, 0));
            if (resident < 1) throw std::runtime_error("L2 kernel has no resident launch configuration");
            config.blocks_per_sm = std::min(config.blocks_per_sm, resident);
            // Reuse within a launch amortizes host launch gaps and the read
            // reduction. .cg accesses still go through L2 on every pass.
            constexpr int passes = 64;
            auto execute = [&](cudaStream_t s) { launch_memory(kind, source.get(), dest.get(), buffer_bytes / 16, sink.get(), sms, config, s, passes); };
            const auto timing = time_at_least(execute, stream);
            const double pass_ms = timing.per_iteration_ms / passes;
            const double bandwidth = double(working_set) / pass_ms / 1e6;
            if (inside) plateau[kind].push_back(bandwidth);
            out << kind << ',' << mib << ',' << buffer_bytes << ',' << working_set << ',' << config.blocks_per_sm
                << ',' << config.threads << ',' << timing.iterations << ',' << passes << ',' << timing.total_ms << ','
                << pass_ms << ',' << bandwidth << ',' << (inside ? 1 : 0) << '\n';
        }
    }
    if (plateau_sizes.empty()) throw std::runtime_error("no L2 plateau points satisfy 4 MiB <= working set <= L2/2");
    int device = 0, clock_khz = 0, bus_bits = 0;
    T1_CUDA(cudaGetDevice(&device));
    const bool have_clock = cudaDeviceGetAttribute(&clock_khz, cudaDevAttrMemoryClockRate, device) == cudaSuccess;
    const bool have_bus = cudaDeviceGetAttribute(&bus_bits, cudaDevAttrGlobalMemoryBusWidth, device) == cudaSuccess;
    cudaGetLastError(); // Optional attribute queries may leave an unsupported error.
    auto limits = new_output(root / "bandwidth/limits.json");
    limits << "{\n  \"hbm_read_GBs\": " << peaks.at("read").bandwidth
           << ",\n  \"hbm_copy_GBs\": " << peaks.at("copy").bandwidth
           << ",\n  \"hbm_write_GBs\": " << peaks.at("write").bandwidth
           << ",\n  \"cudaMemcpy_D2D_GBs\": " << peaks.at("cudaMemcpyD2D").bandwidth
           << ",\n  \"l2_read_GBs_plateau\": " << quantile(plateau.at("read"), .5)
           << ",\n  \"l2_copy_GBs_plateau\": " << quantile(plateau.at("copy"), .5)
           << ",\n  \"l2_plateau_range_MiB\": [" << plateau_sizes.front() << ',' << plateau_sizes.back()
           << "],\n  \"l2_size_bytes\": " << l2
           << ",\n  \"l2_plateau_rule\": \"median of sampled points with 4 MiB <= total distinct working set <= reported L2 / 2\""
           << ",\n  \"theoretical_dram_GBs_reference_only\": ";
    if (have_clock && have_bus && clock_khz > 0 && bus_bits > 0) {
        const double theoretical = 2.0 * double(clock_khz) * 1000 * double(bus_bits) / 8 / 1e9;
        limits << theoretical;
        std::cout << "Theoretical DRAM bandwidth (attribute reference only): " << theoretical << " GB/s\n";
    } else { limits << "null"; std::cout << "Theoretical DRAM bandwidth (attribute reference only): NA\n"; }
    limits << "\n}\n";
}
bool floors(const std::filesystem::path& root, const std::vector<Config>& cfgs, const Options& opts,
            cudaStream_t stream, int sms, LaunchConfig launch) {
    auto out = new_output(root / "bandwidth/pass_floor.csv");
    out << "N,batch,batch_mode,timing_mode,copy_kind,trials,iters_per_trial,time_ms_median,time_ms_min,time_ms_p10,time_ms_p90,bytes_one_pass,status,note\n";
    const int trials = opts.integer("--trials", 15), iters = opts.integer("--iters", 20), warmup = opts.integer("--warmup", 3);
    bool failed = false;
    for (const auto& cfg : cfgs) for (const std::string kind : {"inplace", "outofplace"}) {
        auto prefix = [&](const std::string& mode) {
            out << cfg.n << ',' << cfg.batch << ',' << cfg.batch_mode << ',' << mode << ',' << kind << ','
                << trials << ',' << (mode == "hot" ? iters : 1) << ',';
        };
        try {
            check_fft_iters(cfg.n, iters);
            const size_t count = elements(cfg.n, cfg.batch), bytes = count * 16;
            DeviceBuffer<cuDoubleComplex> input(count), data(count), dest(kind == "outofplace" ? count : 0);
            fill_input(input.get(), count, stream);
            auto restore = [&](cudaStream_t s) { T1_CUDA(cudaMemcpyAsync(data.get(), input.get(), bytes, cudaMemcpyDeviceToDevice, s)); };
            auto execute = [&](cudaStream_t s) {
                copy16<<<sms * launch.blocks_per_sm, launch.threads, 0, s>>>(reinterpret_cast<const double2*>(data.get()),
                    reinterpret_cast<double2*>(kind == "inplace" ? data.get() : dest.get()), count);
                T1_CUDA(cudaGetLastError());
            };
            L2Flush flush;
            std::vector<Stats> statistics;
            for (const std::string mode : {"hot", "cold"})
                statistics.push_back(time_trials(execute, restore, flush, stream, mode, trials, iters, warmup));
            size_t index = 0;
            for (const std::string mode : {"hot", "cold"}) {
                prefix(mode); write_stats(out, statistics[index++]);
                out << ',' << 2 * bytes << ",ok,\"16-byte vector load/store\"\n";
            }
        } catch (const std::exception& error) {
            failed = true;
            for (const std::string mode : {"hot", "cold"}) {
                prefix(mode); out << "NA,NA,NA,NA," << 32 * elements(cfg.n, cfg.batch) << ",error," << csv(error.what()) << '\n';
            }
            std::cerr << "pass floor N=" << cfg.n << " batch=" << cfg.batch << ": " << error.what() << '\n';
            cudaGetLastError();
        }
    }
    return failed;
}
int profile_copy(const Options& opts) {
    const size_t mib = unsigned_value(opts.get("--profile-copy-mib"));
    if (mib > std::numeric_limits<size_t>::max() / MiB) throw std::runtime_error("working set overflow");
    const size_t bytes = mib * MiB / 2;
    Stream stream;
    DeviceBuffer<double2> source(bytes / 16), dest(bytes / 16);
    T1_CUDA(cudaMemsetAsync(source.get(), 0, bytes, stream.value));
    T1_CUDA(cudaMemsetAsync(dest.get(), 0, bytes, stream.value));
    const int blocks = device_properties().multiProcessorCount * 4;
    for (int i = 0; i < 3; ++i) copy16<<<blocks, 256, 0, stream.value>>>(source.get(), dest.get(), bytes / 16);
    T1_CUDA(cudaGetLastError());
    T1_CUDA(cudaStreamSynchronize(stream.value));
    {
        NvtxRange range("prof/bwcopy/WS" + std::to_string(mib));
        copy16<<<blocks, 256, 0, stream.value>>>(source.get(), dest.get(), bytes / 16);
        T1_CUDA(cudaGetLastError());
    }
    T1_CUDA(cudaStreamSynchronize(stream.value));
    return 0;
}
} // namespace
int main(int argc, char** argv) {
    try {
        Options opts(argc, argv, {"--help"}, {"--tag", "--log2", "--n", "--batch", "--batch-modes",
                    "--trials", "--iters", "--warmup", "--hbm-mib", "--profile-copy-mib"});
        if (opts.has("--help")) {
            std::cout << "bwtest --tag TAG [--log2 16,...,24] [--batch-modes b1,b8,t25] [--trials 15] [--iters 20]\n"
                         "  --hbm-mib >=2048 (per buffer); --profile-copy-mib SIZE (sum of source+dest MiB)\n"; return 0;
        }
        const auto root = result_root(opts.get("--tag"));
        if (opts.has("--profile-copy-mib")) return profile_copy(opts);
        const auto cfgs = configs(opts);
        const size_t hbm_mib = unsigned_value(opts.get("--hbm-mib", "2048"));
        if (hbm_mib < 2048 || hbm_mib > std::numeric_limits<size_t>::max() / MiB)
            throw std::runtime_error("--hbm-mib must be >= 2048 and fit size_t");
        Stream stream;
        const int sms = device_properties().multiProcessorCount;
        const auto peaks = hbm(root, hbm_mib * MiB, stream.value, sms);
        l2_and_limits(root, peaks, stream.value, sms);
        return floors(root, cfgs, opts, stream.value, sms, peaks.at("copy").launch) ? 1 : 0;
    } catch (const std::exception& error) {
        std::cerr << "bwtest: " << error.what() << '\n'; return 1;
    }
}
