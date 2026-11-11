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
    double maximum = 0.0;
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
            error_squared += dx * dx + dy * dy;
            reference_squared += static_cast<long double>(reference.x) * reference.x
                                 + static_cast<long double>(reference.y) * reference.y;
            maximum = std::max(maximum, static_cast<double>(std::sqrt(dx * dx + dy * dy)));
        }
    }
    const long double relative = reference_squared == 0.0L ? std::sqrt(error_squared)
                                                                          : std::sqrt(error_squared / reference_squared);
    return {relative, maximum};
}

enum class Outcome { passed, failed, skipped };

Outcome run_config(size_t n, int batch, size_t cap, size_t host_cap, fft2::PlanOptions options = {}) {
    const size_t count = n * static_cast<size_t>(batch);
    const size_t bytes = count * sizeof(cuDoubleComplex);
    // Default split uses <= 4096-entry tables; kPlanReserve bounds them.
    if (3 * bytes + kPlanReserve > cap || bytes + 16 * kMiB > host_cap) {
        std::cout << "N=" << n << " batch=" << batch << " SKIP memory_cap"
                  << " minimum_device_bytes=" << 3 * bytes + kPlanReserve << " device_cap=" << cap
                  << " host_bytes=" << bytes + 16 * kMiB << " host_cap=" << host_cap << '\n';
        return Outcome::skipped;
    }

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
            std::cout << "N=" << n << " batch=" << batch << " SKIP memory_cap"
                      << " required_device_bytes=" << required << " device_cap=" << cap
                      << " cufft_work_bytes=" << work_bytes << '\n';
            return Outcome::skipped;
        }

        // Declared before 'cufft' so the work area outlives the cuFFT handle.
        if (work_bytes != 0) {
            check_cuda(cudaMalloc(&cufft_work.data, work_bytes), "allocate cuFFT work area");
            check_cufft(cufftSetWorkArea(cufft.value, cufft_work.data), "set cuFFT work area");
        }
        check_cufft(cufftSetStream(cufft.value, stream.value), "bind cuFFT nonblocking stream");
        DeviceBytes input(bytes);
        DeviceBytes output(bytes);
        fft2::Plan plan(n, batch, options);
        if (plan.n() != n || plan.batch() != batch || plan.workspace_bytes() != bytes
            || static_cast<size_t>(plan.n1()) * static_cast<size_t>(plan.n2()) != n) {
            throw std::runtime_error("Plan getters / workspace size disagree with requested configuration");
        }
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

        plan.execute(input.complex_data(), output.complex_data(), stream.value);
        const Error out_of_place = compare(output.complex_data(), reference, stream.value);
        // cuFFT and the out-of-place path have left input untouched.
        plan.execute(input.complex_data(), input.complex_data(), stream.value);
        const Error in_place = compare(input.complex_data(), reference, stream.value);
        const bool passed = out_of_place.relative_l2 <= kTolerance && in_place.relative_l2 <= kTolerance;
        std::cout << "N=" << n << " batch=" << batch << " N1=" << plan.n1() << " N2=" << plan.n2()
                  << " oop_rel_l2=" << out_of_place.relative_l2 << " oop_max_abs=" << out_of_place.max_absolute
                  << " inplace_rel_l2=" << in_place.relative_l2 << " inplace_max_abs=" << in_place.max_absolute
                  << (passed ? " PASS" : " FAIL") << '\n';
        return passed ? Outcome::passed : Outcome::failed;
    } catch (const std::exception& error) {
        std::cout << "N=" << n << " batch=" << batch << " FAIL error=" << error.what() << '\n';
        return Outcome::failed;
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
    int passed = 0;
    int failed = 0;
    int skipped = 0;
    try {
        bool describe = false;
        size_t cap = 6144 * kMiB;
        size_t host_cap = 2048 * kMiB;
        for (int index = 1; index < argc; ++index) {
            const std::string argument(argv[index]);
            if (argument == "--describe") {
                describe = true;
            } else if ((argument == "--max-device-mib" || argument == "--max-host-mib") && index + 1 < argc) {
                const size_t value = parse_mib(argv[++index]);
                if (argument == "--max-device-mib") { cap = value; } else { host_cap = value; }
            } else if (argument == "--help") {
                std::cout << "usage: fft2_test [--describe] [--max-device-mib 6144] [--max-host-mib 2048]\n"
                          << "--describe prints default batch=1 plans for every N, without executing FFTs.\n";
                return 0;
            } else {
                throw std::runtime_error("unknown option or missing value: " + argument);
            }
        }
        if (describe) {
            for (int exponent = 16; exponent <= 24; ++exponent) {
                const fft2::Plan plan(size_t{1} << exponent, 1);
                std::cout << plan.describe() << '\n';
            }
            std::cout << "SUMMARY described=9 (no FFT execution)\n";
            return 0;
        }
        size_t free_bytes = 0;
        size_t total_bytes = 0;
        check_cuda(cudaMemGetInfo(&free_bytes, &total_bytes), "query available device memory");
        cap = std::min(cap, free_bytes - free_bytes / 10);  // Leave 10% of free VRAM outside the test budget.
        std::cout << "memory_device_cap=" << cap << " memory_host_cap=" << host_cap
                  << " free_device_bytes=" << free_bytes << " total_device_bytes=" << total_bytes << '\n';
        const bool api_ok = api_checks();
        for (int exponent = 16; exponent <= 24; ++exponent) {
            for (int batch : {1, 3, 8}) {
                const Outcome result = run_config(size_t{1} << exponent, batch, cap, host_cap);
                if (result == Outcome::passed) { ++passed; }
                else if (result == Outcome::failed) { ++failed; }
                else { ++skipped; }
            }
        }
        // Exercise nondefault factors and partial tiles in the GPU gate too.
        for (fft2::PlanOptions options : {fft2::PlanOptions{256, 3, 5}, fft2::PlanOptions{1024, 2, 3}}) {
            const Outcome result = run_config(size_t{1} << 18, 3, cap, host_cap, options);
            if (result == Outcome::passed) { ++passed; }
            else if (result == Outcome::failed) { ++failed; }
            else { ++skipped; }
        }
        std::cout << "SUMMARY passed=" << passed << " failed=" << failed << " skipped=" << skipped
                  << " api=" << (api_ok ? "PASS" : "FAIL") << '\n';
        return failed == 0 && passed != 0 && api_ok ? 0 : 1;
    } catch (const std::exception& error) {
        std::cerr << "FAIL error=" << error.what() << '\n';
        std::cout << "SUMMARY passed=" << passed << " failed=" << failed + 1 << " skipped=" << skipped << '\n';
        return 1;
    }
}
