#include "common/options.hpp"
#include "common/timing.cuh"
#include "common/correctness.cuh"
#include "common/nvtx.hpp"
#include "backends/backend.hpp"
#include <cerrno>
#include <cstring>
#include <iostream>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>

using namespace measure;
namespace {
constexpr const char* header = "impl,N,log2N,batch,batch_mode,timing_mode,trials,iters_per_trial,time_ms_median,time_ms_min,time_ms_p10,time_ms_p90,rel_l2_err,max_abs_err,status,note,impl_detail\n";
const std::vector<std::string> modes = {"hot", "cold"};
fft2::PlanOptions fft2_options(const Options& opts) {
    fft2::PlanOptions options{opts.nonnegative_integer("--fft2-n1"), opts.nonnegative_integer("--fft2-tile-cols"),
                              opts.nonnegative_integer("--fft2-tile-rows"),
                              opts.nonnegative_integer("--fft2-index-mode"), opts.nonnegative_integer("--fft2-smem-padding"),
                              opts.nonnegative_integer("--fft2-tile-policy"), opts.nonnegative_integer("--fft2-radix-mode")};
    if (options.index_mode > 1) throw std::runtime_error("--fft2-index-mode must be 0 or 1");
    if (options.smem_padding > 2) throw std::runtime_error("--fft2-smem-padding must be 0, 1 or 2");
    if (options.tile_policy > 1) throw std::runtime_error("--fft2-tile-policy must be 0 or 1");
    if (options.radix_mode > 2) throw std::runtime_error("--fft2-radix-mode must be 0, 1 or 2");
    return options;
}
std::string config_id(const std::string& impl, const Config& cfg) {
    return impl + "_N" + std::to_string(cfg.n) + "_b" + std::to_string(cfg.batch) + "_" + cfg.batch_mode;
}
void prefix(std::ostream& out, const std::string& impl, const Config& cfg,
            const std::string& mode, int trials, int iters) {
    out << csv(impl) << ',' << cfg.n << ',' << int(std::log2(double(cfg.n))) << ',' << cfg.batch << ','
        << cfg.batch_mode << ',' << mode << ',' << trials << ',' << (mode == "hot" ? iters : 1) << ',';
}
void status_rows(std::ostream& out, const std::string& impl, const Config& cfg, int trials, int iters,
                 const std::string& status, const std::string& reason) {
    for (const auto& mode : modes) {
        prefix(out, impl, cfg, mode, trials, iters);
        out << "NA,NA,NA,NA,NA,NA," << status << ',' << csv(reason) << ",\n";
    }
}
int single(const Options& opts, const Config& cfg, const std::string& impl) {
    const auto root = result_root(opts.get("--tag"));
    const bool profile = opts.has("--profile"), exporting = opts.has("--export-vkfft");
    auto fft = backend(impl, exporting, fft2_options(opts), opts.has("--fft2-out-of-place"));
    const auto label = fft->name();
    const int trials = opts.integer("--trials", 15), iters = opts.integer("--iters", 20);
    const int warmup = opts.integer("--warmup", 3);
    std::string reason;
    if (!fft->supports(cfg.n, cfg.batch, &reason)) {
        if (profile || exporting) { std::cout << "unsupported: " << reason << '\n'; return 3; }
        auto out = new_output(root / "sweep/rows" / (config_id(label, cfg) + ".csv"));
        status_rows(out, label, cfg, trials, iters, "unsupported", reason);
        return 0;
    }
    Stream stream;
    fft->plan(cfg.n, cfg.batch);
    const auto detail = fft->detail();
    if (!detail.empty()) std::cout << "impl_detail=" << detail << '\n';
    if (exporting) {
        fft->export_kernels(root / "vkfft_kernels" / ("N" + std::to_string(cfg.n) + "_b" + std::to_string(cfg.batch)));
        fft->destroy(); return 0;
    }
    const size_t count = elements(cfg.n, cfg.batch), bytes = count * sizeof(cuDoubleComplex);
    DeviceBuffer<cuDoubleComplex> input(count);
    fill_input(input.get(), count, stream.value);
    auto restore = [&](cudaStream_t s) {
        T1_CUDA(cudaMemcpyAsync(fft->buffer(), input.get(), bytes, cudaMemcpyDeviceToDevice, s));
    };
    auto execute = [&](cudaStream_t s) { fft->execute(s); };
    if (profile) {
        for (int i = 0; i < warmup; ++i) { restore(stream.value); execute(stream.value); }
        restore(stream.value);
        T1_CUDA(cudaStreamSynchronize(stream.value));
        {
            NvtxRange range("prof/" + label + "/N" + std::to_string(cfg.n) + "/b" + std::to_string(cfg.batch));
            execute(stream.value); // Exactly one execution, including every batch's kernels.
        }
        T1_CUDA(cudaStreamSynchronize(stream.value));
        fft->destroy(); return 0;
    }
    check_fft_iters(cfg.n, iters);
    const double threshold = std::stod(opts.get("--threshold", "1e-12"));
    if (!(threshold > 0) || !std::isfinite(threshold)) throw std::runtime_error("invalid correctness threshold");
    Errors error{};
    std::string note = "seed=12345";
    bool reference_ok = true;
    {
        Reference reference(cfg.n, cfg.batch);
        auto* ref = reference.run(input.get(), stream.value);
        restore(stream.value); execute(stream.value);
        error = compare(fft->output(), ref, count, stream.value);
        if (opts.has("--verify-fftw") && cfg.batch == 1 && cfg.n <= (size_t(1) << 20)) {
            const auto check = verify_fftw(input.get(), ref, cfg.n, stream.value);
            reference_ok = std::isfinite(check.relative_l2) && check.relative_l2 <= threshold;
            std::ostringstream fftw_note;
            fftw_note << std::setprecision(17) << "; cufft_vs_fftw_rel_l2=" << check.relative_l2
                      << "; cufft_vs_fftw_max_abs=" << check.maximum;
            note += fftw_note.str();
            std::cout << std::setprecision(17) << "cuFFT vs FFTW rel_l2=" << check.relative_l2
                      << " max_abs=" << check.maximum << '\n';
        }
    }
    const std::string status = reference_ok && std::isfinite(error.relative_l2) &&
                               error.relative_l2 <= threshold ? "ok" : "wrong";
    L2Flush flush;
    std::vector<Stats> statistics;
    for (const auto& mode : modes)
        statistics.push_back(time_trials(execute, restore, flush, stream.value, mode, trials, iters, warmup));
    auto out = new_output(root / "sweep/rows" / (config_id(label, cfg) + ".csv"));
    for (size_t i = 0; i < modes.size(); ++i) {
        prefix(out, label, cfg, modes[i], trials, iters); write_stats(out, statistics[i]);
        out << ',' << error.relative_l2 << ',' << error.maximum << ',' << status << ',' << csv(note)
            << ',' << csv(detail) << '\n';
    }
    fft->destroy();
    return status == "ok" ? 0 : 2;
}
// The legacy API calls exit() on CUDA errors. A fresh process per config also
// releases a poisoned CUDA context after an OOM/launch fault, so the sweep can
// always attempt subsequent configs without changing the legacy API or code.
int sweep(const Options& opts, const std::vector<Config>& cfgs, const std::vector<std::string>& impls) {
    const auto root = result_root(opts.get("--tag"));
    auto out = new_output(root / "sweep/raw.csv"); out << header; out.flush();
    bool failed = false;
    for (const auto& cfg : cfgs) for (const auto& impl : impls) {
        const auto label = backend(impl, false, fft2_options(opts), opts.has("--fft2-out-of-place"))->name();
        const std::string id = config_id(label, cfg);
        const auto row_path = root / "sweep/rows" / (id + ".csv");
        const auto log_path = root / "sweep/config_logs" / (id + ".log");
        if (std::filesystem::exists(row_path) || std::filesystem::exists(log_path))
            throw std::runtime_error("duplicate config or existing worker outputs: " + id);
        std::filesystem::create_directories(log_path.parent_path());
        std::vector<std::string> args = {"/proc/self/exe", "--worker", "--tag", opts.get("--tag"),
            "--impls", impl, "--n", std::to_string(cfg.n), "--batch", std::to_string(cfg.batch),
            "--batch-modes", cfg.batch_mode, "--trials", opts.get("--trials", "15"),
            "--iters", opts.get("--iters", "20"), "--warmup", opts.get("--warmup", "3"),
            "--threshold", opts.get("--threshold", "1e-12")};
        if (opts.has("--verify-fftw")) args.push_back("--verify-fftw");
        for (const auto* key : {"--fft2-n1", "--fft2-tile-cols", "--fft2-tile-rows",
                                "--fft2-index-mode", "--fft2-smem-padding", "--fft2-tile-policy", "--fft2-radix-mode"}) {
            if (opts.has(key)) { args.push_back(key); args.push_back(opts.get(key)); }
        }
        if (opts.has("--fft2-out-of-place")) args.push_back("--fft2-out-of-place");
        std::vector<char*> argv;
        for (auto& arg : args) argv.push_back(arg.data());
        argv.push_back(nullptr);
        const pid_t child = fork();
        if (child < 0) throw std::runtime_error(std::string("fork: ") + std::strerror(errno));
        if (child == 0) {
            const int fd = open(log_path.c_str(), O_WRONLY | O_CREAT | O_EXCL, 0644);
            if (fd < 0 || dup2(fd, STDOUT_FILENO) < 0 || dup2(fd, STDERR_FILENO) < 0) _exit(126);
            close(fd);
            execv(argv[0], argv.data()); _exit(127);
        }
        int wait_status = 0;
        while (waitpid(child, &wait_status, 0) < 0) {
            if (errno != EINTR) throw std::runtime_error("waitpid failed");
        }
        const int code = WIFEXITED(wait_status) ? WEXITSTATUS(wait_status) : 128 + WTERMSIG(wait_status);
        if ((code == 0 || code == 2) && std::filesystem::exists(row_path)) {
            std::ifstream rows(row_path); out << rows.rdbuf();
        } else {
            std::ifstream log(log_path);
            std::ostringstream detail; detail << log.rdbuf();
            status_rows(out, label, cfg, opts.integer("--trials", 15), opts.integer("--iters", 20), "error",
                        "worker exit " + std::to_string(code) + "; " + log_path.string() + "; " + detail.str().substr(0, 2000));
        }
        out.flush(); failed = failed || code != 0;
        std::cout << id << ": " << (code == 0 ? "completed" : "exit " + std::to_string(code)) << '\n';
    }
    return failed ? 1 : 0;
}
} // namespace
int main(int argc, char** argv) {
    try {
        Options opts(argc, argv, {"--worker", "--profile", "--export-vkfft", "--versions", "--verify-fftw", "--fft2-out-of-place", "--help"},
                     {"--tag", "--n", "--log2", "--batch", "--batch-modes", "--impl", "--impls", "--trials", "--iters", "--warmup", "--threshold",
                      "--fft2-n1", "--fft2-tile-cols", "--fft2-tile-rows", "--fft2-index-mode", "--fft2-smem-padding", "--fft2-tile-policy", "--fft2-radix-mode"});
        if (opts.has("--help")) {
            std::cout << "fft_bench --tag TAG [--log2 16,...,24] [--batch-modes b1,b8,t25] [--impls legacy,cufft,vkfft,fft2]\n"
                         "  [--trials 15] [--iters 20] [--warmup 3] [--threshold 1e-12] [--verify-fftw]\n"
                         "  [--impl fft2] [--fft2-n1 0] [--fft2-tile-cols 0] [--fft2-tile-rows 0] [--fft2-out-of-place]\n"
                         "  [--fft2-index-mode 0|1] [--fft2-smem-padding 0|1|2] (default: 0)\n"
                         "  [--fft2-tile-policy 0|1] [--fft2-radix-mode 0|1|2] (default: 0)\n"
                         "  --profile | --export-vkfft: requires exactly one --n, --batch and --impls config\n";
            return 0;
        }
        if (opts.has("--versions")) {
            int version = 0; T1_CUFFT(cufftGetVersion(&version));
            std::cout << "cuFFT version: " << version << "\nVkFFT commit: " << T1_VKFFT_COMMIT << '\n'; return 0;
        }
        const auto cfgs = configs(opts);
        if (opts.has("--impl") && opts.has("--impls")) throw std::runtime_error("choose --impl or --impls");
        const auto impls = split(opts.get("--impl", opts.get("--impls", "legacy,cufft,vkfft,fft2")));
        for (const auto& impl : impls) {
            auto checked = backend(impl, false, fft2_options(opts), opts.has("--fft2-out-of-place"));
            (void)checked;
        }
        if (opts.has("--profile") && opts.has("--export-vkfft")) throw std::runtime_error("choose profile or export");
        if (opts.has("--worker") || opts.has("--profile") || opts.has("--export-vkfft")) {
            if (cfgs.size() != 1 || impls.size() != 1) throw std::runtime_error("single-config mode requires one size/batch/impl");
            return single(opts, cfgs[0], impls[0]);
        }
        return sweep(opts, cfgs, impls);
    } catch (const std::exception& error) {
        std::cerr << "fft_bench: " << error.what() << '\n'; return 1;
    }
}
