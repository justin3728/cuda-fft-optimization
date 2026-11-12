#include "fft2.h"

#include <cuda_runtime.h>
#include <cufft.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr size_t kMiB = size_t{1} << 20;
constexpr size_t kPlanReserve = 16 * kMiB;  // Tables plus a margin, not a performance measurement.
constexpr long double kTolerance = 1e-12L;

void check_cuda(cudaError_t status, const char* operation) {
    if (status != cudaSuccess) {
        throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(status));
    }
}

void check_cufft(cufftResult status, const char* operation) {
    if (status != CUFFT_SUCCESS) {
        throw std::runtime_error(std::string(operation) + ": cuFFT error " + std::to_string(static_cast<int>(status)));
    }
}

struct DeviceBytes {
    void* data = nullptr;
    explicit DeviceBytes(size_t bytes) {
        if (bytes != 0) {
            check_cuda(cudaMalloc(&data, bytes), "allocate test device buffer");
        }
    }
    ~DeviceBytes() { if (data != nullptr) { (void)cudaFree(data); } }
    DeviceBytes(const DeviceBytes&) = delete;
    DeviceBytes& operator=(const DeviceBytes&) = delete;
    cuDoubleComplex* complex_data() { return static_cast<cuDoubleComplex*>(data); }
};

struct Stream {
    cudaStream_t value = nullptr;
    Stream() { check_cuda(cudaStreamCreateWithFlags(&value, cudaStreamNonBlocking), "create nonblocking stream"); }
    ~Stream() { (void)cudaStreamDestroy(value); }
    Stream(const Stream&) = delete;
    Stream& operator=(const Stream&) = delete;
};

struct CufftPlan {
    cufftHandle value = 0;
    CufftPlan() { check_cufft(cufftCreate(&value), "create cuFFT plan"); }
    ~CufftPlan() { (void)cufftDestroy(value); }
    CufftPlan(const CufftPlan&) = delete;
    CufftPlan& operator=(const CufftPlan&) = delete;
};

struct Error {
    long double relative_l2;
    double max_absolute;
};

Error compare(const cuDoubleComplex* actual, const std::vector<cuDoubleComplex>& expected, cudaStream_t stream) {
    // Keep host memory to one full reference array and one bounded transfer tile.
    std::vector<cuDoubleComplex> chunk(std::min(expected.size(), kMiB));
    long double error_squared = 0.0L;
    long double reference_squared = 0.0L;
    long double maximum_squared = 0.0L;
    for (size_t first = 0; first < expected.size(); first += chunk.size()) {
        const size_t count = std::min(chunk.size(), expected.size() - first);
        check_cuda(cudaMemcpyAsync(chunk.data(), actual + first, count * sizeof(cuDoubleComplex),
                                   cudaMemcpyDeviceToHost, stream), "read FFT result");
        check_cuda(cudaStreamSynchronize(stream), "complete result transfer / detect asynchronous FFT errors");
        for (size_t index = 0; index < count; ++index) {
            const cuDoubleComplex reference = expected[first + index];
            const cuDoubleComplex value = chunk[index];
            if (!std::isfinite(value.x) || !std::isfinite(value.y)
                || !std::isfinite(reference.x) || !std::isfinite(reference.y)) {
                return {std::numeric_limits<long double>::infinity(), std::numeric_limits<double>::infinity()};
            }
            const long double dx = static_cast<long double>(value.x) - reference.x;
            const long double dy = static_cast<long double>(value.y) - reference.y;
            const long double difference_squared = dx * dx + dy * dy;
            error_squared += difference_squared;
            reference_squared += static_cast<long double>(reference.x) * reference.x
                                 + static_cast<long double>(reference.y) * reference.y;
            maximum_squared = std::max(maximum_squared, difference_squared);
        }
    }
    const long double relative = reference_squared == 0.0L ? std::sqrt(error_squared)
                                                                          : std::sqrt(error_squared / reference_squared);
    return {relative, static_cast<double>(std::sqrt(maximum_squared))};
}

enum class Outcome { passed, failed, skipped };

struct Counts {
    int passed = 0;
    int failed = 0;
    int skipped = 0;

    void add(Outcome result) {
        if (result == Outcome::passed) { ++passed; }
        else if (result == Outcome::failed) { ++failed; }
        else { ++skipped; }
    }
};

struct Summary {
    Counts total;
    Counts axes[3][2][3][2];

    void add(Outcome result, fft2::PlanOptions options) {
        total.add(result);
        axes[options.radix_mode][options.index_mode][options.smem_padding][options.tile_policy].add(result);
    }
};

std::vector<fft2::PlanOptions> variants_for(fft2::PlanOptions options, bool variants) {
    std::vector<fft2::PlanOptions> result;
    for (int mode = 0; mode <= (variants ? 1 : 0); ++mode) {
        for (int padding = 0; padding <= (variants ? 2 : 0); ++padding) {
            for (int policy = 0; policy <= (variants ? 1 : 0); ++policy) {
                options.index_mode = mode;
                options.smem_padding = padding;
                options.tile_policy = policy;
                result.push_back(options);
            }
        }
    }
    // Bound the L4 gate: test new radices against both tile policies with
    // baseline indexing/padding, retaining all existing v1 axis combinations.
    if (variants) {
        options.index_mode = 0;
        options.smem_padding = 0;
        for (int radix : {1, 2}) {
            for (int policy : {0, 1}) {
                options.radix_mode = radix;
                options.tile_policy = policy;
                result.push_back(options);
            }
        }
    }
    return result;
}

std::string config_label(size_t n, int batch, fft2::PlanOptions options) {
    std::ostringstream label;
    label << "N=" << n << " batch=" << batch << " requested_N1=" << options.n1
          << " requested_C=" << options.tile_cols << " requested_R=" << options.tile_rows
          << " index_mode=" << options.index_mode << " smem_padding=" << options.smem_padding
          << " tile_policy=" << options.tile_policy << " radix_mode=" << options.radix_mode;
    return label.str();
}

bool shared_fits(size_t n, fft2::PlanOptions options, size_t limit) {
    int log_n = 0;
    for (size_t value = n; value > 1; value >>= 1) { ++log_n; }
    const size_t n1 = options.n1 == 0 ? size_t{1} << (log_n / 2) : static_cast<size_t>(options.n1);
    const size_t n2 = n / n1;
    // Both automatic policies can fall back to one lane; explicit widths override.
    // Do not catch arbitrary plan/CUDA errors as skips.
    const size_t minimum = 1;
    const size_t cols = options.tile_cols == 0 ? minimum : static_cast<size_t>(options.tile_cols);
    const size_t rows = options.tile_rows == 0 ? minimum : static_cast<size_t>(options.tile_rows);
    return n1 * (cols + static_cast<size_t>(options.smem_padding)) * sizeof(cuDoubleComplex) <= limit
        && n2 * (rows + static_cast<size_t>(options.smem_padding)) * sizeof(cuDoubleComplex) <= limit;
}

void run_config(size_t n, int batch, size_t cap, size_t host_cap, size_t shared_limit,
                bool variants, Summary& summary, fft2::PlanOptions base_options = {}) {
    const size_t count = n * static_cast<size_t>(batch);
    const size_t bytes = count * sizeof(cuDoubleComplex);
    std::vector<fft2::PlanOptions> eligible;
    for (const auto options : variants_for(base_options, variants)) {
        if (!shared_fits(n, options, shared_limit)) {
            std::cout << config_label(n, batch, options) << " SKIP shared_memory_budget"
                      << " optin_limit=" << shared_limit << '\n';
            summary.add(Outcome::skipped, options);
        } else if (3 * bytes + kPlanReserve > cap || bytes + 16 * kMiB > host_cap) {
            std::cout << config_label(n, batch, options) << " SKIP memory_cap"
                      << " minimum_device_bytes=" << 3 * bytes + kPlanReserve << " device_cap=" << cap
                      << " host_bytes=" << bytes + 16 * kMiB << " host_cap=" << host_cap << '\n';
            summary.add(Outcome::skipped, options);
        } else {
            eligible.push_back(options);
        }
    }
    if (eligible.empty()) { return; }

    try {
        Stream stream;
        // Query exact cuFFT work size with automatic allocation disabled, before
        // allocating the transform data. No guessed cuFFT workspace multiplier.
        DeviceBytes cufft_work(0);
        CufftPlan cufft;
        check_cufft(cufftSetAutoAllocation(cufft.value, 0), "disable cuFFT automatic allocation");
        int dimensions[1] = {static_cast<int>(n)};
        size_t work_bytes = 0;
        check_cufft(cufftMakePlanMany(cufft.value, 1, dimensions, nullptr, 1, static_cast<int>(n),
                                     nullptr, 1, static_cast<int>(n), CUFFT_Z2Z, batch, &work_bytes),
                    "plan batched cuFFT reference");
        const size_t required = 3 * bytes + kPlanReserve + work_bytes;
        if (required > cap) {
            for (const auto options : eligible) {
                std::cout << config_label(n, batch, options) << " SKIP memory_cap"
                          << " required_device_bytes=" << required << " device_cap=" << cap
                          << " cufft_work_bytes=" << work_bytes << '\n';
                summary.add(Outcome::skipped, options);
            }
            return;
        }

        // Declared before 'cufft' so the work area outlives the cuFFT handle.
        if (work_bytes != 0) {
            check_cuda(cudaMalloc(&cufft_work.data, work_bytes), "allocate cuFFT work area");
            check_cufft(cufftSetWorkArea(cufft.value, cufft_work.data), "set cuFFT work area");
        }
        check_cufft(cufftSetStream(cufft.value, stream.value), "bind cuFFT nonblocking stream");
        DeviceBytes input(bytes);
        DeviceBytes output(bytes);
        // Generate input and execute cuFFT once per (N, batch, split/tile case),
        // then reuse both across all variants. Only one fft2 plan is live at a
        // time, preserving the original device/host memory caps.
        std::vector<cuDoubleComplex> reference(count);
        std::mt19937_64 rng(static_cast<uint64_t>(n) + static_cast<uint64_t>(batch));
        std::uniform_real_distribution<double> random(-1.0, 1.0);
        for (cuDoubleComplex& value : reference) {
            value = make_cuDoubleComplex(random(rng), random(rng));
        }
        check_cuda(cudaMemcpyAsync(input.data, reference.data(), bytes, cudaMemcpyHostToDevice, stream.value),
                   "upload random input");
        check_cufft(cufftExecZ2Z(cufft.value, input.complex_data(), output.complex_data(), CUFFT_FORWARD),
                    "execute cuFFT forward reference");
        check_cuda(cudaMemcpyAsync(reference.data(), output.data, bytes, cudaMemcpyDeviceToHost, stream.value),
                   "read cuFFT reference");
        check_cuda(cudaStreamSynchronize(stream.value), "complete cuFFT reference");

        for (const auto options : eligible) {
            try {
                fft2::Plan plan(n, batch, options);
                if (plan.n() != n || plan.batch() != batch || plan.workspace_bytes() != bytes
                    || static_cast<size_t>(plan.n1()) * static_cast<size_t>(plan.n2()) != n) {
                    throw std::runtime_error("Plan getters / workspace size disagree with requested configuration");
                }
                plan.execute(input.complex_data(), output.complex_data(), stream.value);
                const Error out_of_place = compare(output.complex_data(), reference, stream.value);
                // Preserve input for the next variant, testing aliasing in the
                // output buffer with the same original samples.
                check_cuda(cudaMemcpyAsync(output.data, input.data, bytes, cudaMemcpyDeviceToDevice, stream.value),
                           "restore input for in-place FFT");
                plan.execute(output.complex_data(), output.complex_data(), stream.value);
                const Error in_place = compare(output.complex_data(), reference, stream.value);
                const long double tolerance = options.radix_mode == 0 ? kTolerance : 1e-14L;
                const bool passed = out_of_place.relative_l2 <= tolerance && in_place.relative_l2 <= tolerance;
                std::cout << config_label(n, batch, options) << " " << plan.describe()
                          << " oop_rel_l2=" << out_of_place.relative_l2 << " oop_max_abs=" << out_of_place.max_absolute
                          << " inplace_rel_l2=" << in_place.relative_l2 << " inplace_max_abs=" << in_place.max_absolute
                          << (passed ? " PASS" : " FAIL") << '\n';
                summary.add(passed ? Outcome::passed : Outcome::failed, options);
            } catch (const std::exception& error) {
                std::cout << config_label(n, batch, options) << " FAIL error=" << error.what() << '\n';
                summary.add(Outcome::failed, options);
            }
        }
    } catch (const std::exception& error) {
        for (const auto options : eligible) {
            std::cout << config_label(n, batch, options) << " FAIL error=" << error.what() << '\n';
            summary.add(Outcome::failed, options);
        }
    }
}

template <typename Action>
void expect_error(Action action, const char* name) {
    try {
        action();
    } catch (const std::runtime_error&) {
        return;
    }
    throw std::runtime_error(std::string("expected runtime_error: ") + name);
}

bool api_checks() {
    try {
        expect_error([] { fft2::Plan plan(123, 1); }, "non-power-of-two N");
        expect_error([] { fft2::Plan plan(size_t{1} << 15, 1); }, "N below range");
        expect_error([] { fft2::Plan plan(size_t{1} << 25, 1); }, "N above range");
        expect_error([] { fft2::Plan plan(size_t{1} << 16, 0); }, "zero batch");
        expect_error([] { fft2::Plan plan(size_t{1} << 16, 1, {512, 0, 0}); }, "N2 below range");
        expect_error([] { fft2::Plan plan(size_t{1} << 18, 1, {300, 0, 0}); }, "invalid N1");
        expect_error([] { fft2::Plan plan(size_t{1} << 16, 1, {0, -1, 0}); }, "negative tile");
        expect_error([] { fft2::Plan plan(size_t{1} << 24, 1, {0, 8, 0}); }, "tile above opt-in limit");
        for (int mode : {-1, 2}) {
            expect_error([mode] { fft2::Plan plan(size_t{1} << 16, 1, {0, 0, 0, mode, 0}); },
                         "invalid index mode");
        }
        for (int padding : {-1, 3}) {
            expect_error([padding] { fft2::Plan plan(size_t{1} << 16, 1, {0, 0, 0, 0, padding}); },
                         "invalid shared padding");
        }
        for (int policy : {-1, 2}) {
            expect_error([policy] { fft2::Plan plan(size_t{1} << 16, 1, {0, 0, 0, 0, 0, policy}); },
                         "invalid tile policy");
        }
        for (int radix : {-1, 3}) {
            expect_error([radix] { fft2::Plan plan(size_t{1} << 16, 1, {0, 0, 0, 0, 0, 0, radix}); },
                         "invalid radix mode");
        }
        fft2::Plan plan(size_t{1} << 16, 1);
        expect_error([&plan] { plan.execute(nullptr, nullptr, nullptr); }, "null input/output");
        std::cout << "API checks PASS\n";
        return true;
    } catch (const std::exception& error) {
        std::cout << "API checks FAIL error=" << error.what() << '\n';
        return false;
    }
}

size_t parse_mib(const std::string& value) {
    size_t consumed = 0;
    const unsigned long long amount = std::stoull(value, &consumed);
    if (value.empty() || value.front() == '-' || consumed != value.size() || amount == 0
        || amount > std::numeric_limits<size_t>::max() / kMiB) {
        throw std::runtime_error("memory caps must be positive integer MiB");
    }
    return static_cast<size_t>(amount) * kMiB;
}

}  // namespace

int main(int argc, char** argv) {
    std::cout << std::scientific << std::setprecision(6) << std::unitbuf;
    Summary summary;
    try {
        bool describe = false;
        bool variants = false;
        size_t cap = 6144 * kMiB;
        size_t host_cap = 2048 * kMiB;
        for (int index = 1; index < argc; ++index) {
            const std::string argument(argv[index]);
            if (argument == "--describe") {
                describe = true;
            } else if (argument == "--variants") {
                variants = true;
            } else if ((argument == "--max-device-mib" || argument == "--max-host-mib") && index + 1 < argc) {
                const size_t value = parse_mib(argv[++index]);
                if (argument == "--max-device-mib") { cap = value; } else { host_cap = value; }
            } else if (argument == "--help") {
                std::cout << "usage: fft2_test [--variants] [--describe] [--max-device-mib 6144] [--max-host-mib 2048]\n"
                          << "--variants tests index_mode={0,1} x smem_padding={0,1,2} x tile_policy={0,1},"
                          << " plus radix_mode={1,2} x tile_policy={0,1} at index_mode=smem_padding=0,"
                          << " where shared memory fits.\n"
                          << "--describe prints batch=1 plans for every N, without executing FFTs.\n";
                return 0;
            } else {
                throw std::runtime_error("unknown option or missing value: " + argument);
            }
        }
        int device = 0;
        int shared_limit = 0;
        check_cuda(cudaGetDevice(&device), "get test device");
        check_cuda(cudaDeviceGetAttribute(&shared_limit, cudaDevAttrMaxSharedMemoryPerBlockOptin, device),
                   "query test opt-in shared-memory limit");
        if (shared_limit <= 0) { throw std::runtime_error("device reports no opt-in shared memory"); }
        if (describe) {
            int described = 0;
            int skipped = 0;
            for (int exponent = 16; exponent <= 24; ++exponent) {
                const size_t n = size_t{1} << exponent;
                for (const auto options : variants_for({}, variants)) {
                    if (!shared_fits(n, options, static_cast<size_t>(shared_limit))) {
                        std::cout << config_label(n, 1, options) << " SKIP shared_memory_budget"
                                  << " optin_limit=" << shared_limit << '\n';
                        ++skipped;
                        continue;
                    }
                    const fft2::Plan plan(n, 1, options);
                    std::cout << plan.describe() << '\n';
                    ++described;
                }
            }
            std::cout << "SUMMARY described=" << described << " skipped=" << skipped << " (no FFT execution)\n";
            return 0;
        }
        size_t free_bytes = 0;
        size_t total_bytes = 0;
        check_cuda(cudaMemGetInfo(&free_bytes, &total_bytes), "query available device memory");
        cap = std::min(cap, free_bytes - free_bytes / 10);  // Leave 10% of free VRAM outside the test budget.
        std::cout << "memory_device_cap=" << cap << " memory_host_cap=" << host_cap
                  << " free_device_bytes=" << free_bytes << " total_device_bytes=" << total_bytes
                  << " optin_shared_limit=" << shared_limit << '\n';
        const bool api_ok = api_checks();
        for (int exponent = 16; exponent <= 24; ++exponent) {
            for (int batch : {1, 3, 8}) {
                run_config(size_t{1} << exponent, batch, cap, host_cap, static_cast<size_t>(shared_limit),
                           variants, summary);
            }
        }
        // Exercise nondefault factors and partial tiles in the GPU gate too.
        for (fft2::PlanOptions options : {fft2::PlanOptions{256, 3, 5}, fft2::PlanOptions{1024, 2, 3}}) {
            run_config(size_t{1} << 18, 3, cap, host_cap, static_cast<size_t>(shared_limit),
                       variants, summary, options);
        }
        bool all_axes_executed = true;
        for (const auto options : variants_for({}, variants)) {
            const Counts& axis = summary.axes[options.radix_mode][options.index_mode]
                                             [options.smem_padding][options.tile_policy];
            std::cout << "VARIANT_SUMMARY index_mode=" << options.index_mode
                      << " smem_padding=" << options.smem_padding << " tile_policy=" << options.tile_policy
                      << " radix_mode=" << options.radix_mode << " passed=" << axis.passed
                      << " failed=" << axis.failed << " skipped=" << axis.skipped << '\n';
            all_axes_executed = all_axes_executed && axis.passed != 0;
        }
        std::cout << "SUMMARY passed=" << summary.total.passed << " failed=" << summary.total.failed
                  << " skipped=" << summary.total.skipped
                  << " api=" << (api_ok ? "PASS" : "FAIL")
                  << " axes=" << (all_axes_executed ? "PASS" : "FAIL") << '\n';
        return summary.total.failed == 0 && all_axes_executed && api_ok ? 0 : 1;
    } catch (const std::exception& error) {
        std::cerr << "FAIL error=" << error.what() << '\n';
        std::cout << "SUMMARY passed=" << summary.total.passed << " failed=" << summary.total.failed + 1
                  << " skipped=" << summary.total.skipped << '\n';
        return 1;
    }
}
