/*
 * File: benchmark.cpp
 * Purpose: Reproducible portfolio benchmark for FFTW, custom CUDA FFT, and cuFFT.
 * Target example: NVIDIA A100 (make -B CUDA_ARCH=sm_80)
 * Usage: ./benchmark [--fftw-threads 8] [--csv benchmark_results.csv]
 *
 * Timing policy
 * -------------
 * FFTW:       fftw_execute() only; planning/allocation excluded.
 * MyCUDA:     H2D / device work / D2H measured with CUDA events.
 * MyCUDA E2E: H2D -> FFT -> D2H -> stream synchronization (host wall clock).
 * cuFFT:      device execution measured with CUDA events; E2E measured separately.
 *
 * All implementations use the same deterministic FP64 complex input for each N.
 */

#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cmath>
#include <algorithm>
#include <chrono>
#include <cerrno>
#include <cstring>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <string>

#include <cuda_runtime.h>
#include <cufft.h>
#include <fftw3.h>

#include "fft_cuda.h"

// ================= Benchmark configuration =================
constexpr int WARMUP = 20;
constexpr int REPEAT = 100;
constexpr int MIN_LOG_N = 4;
constexpr int MAX_LOG_N = 20;
constexpr int DEFAULT_FFTW_THREADS = 8;
constexpr double ACCURACY_TOLERANCE = 1e-8;
constexpr uint64_t INPUT_SEED = 12345ULL;

// ================= Error checking =================
#define CUDA_CHECK(call) do { \
    cudaError_t err__ = (call); \
    if (err__ != cudaSuccess) { \
        std::fprintf(stderr, "CUDA Error: %s at line %d\n", \
                     cudaGetErrorString(err__), __LINE__); \
        std::exit(EXIT_FAILURE); \
    } \
} while (0)

#define CUFFT_CHECK(call) do { \
    cufftResult err__ = (call); \
    if (err__ != CUFFT_SUCCESS) { \
        std::fprintf(stderr, "cuFFT Error: %d at line %d\n", \
                     static_cast<int>(err__), __LINE__); \
        std::exit(EXIT_FAILURE); \
    } \
} while (0)

// ================= Utilities =================
bool parse_positive_int(const char *text, int maximum, int &value) {
    errno = 0;
    char *end = nullptr;
    const long parsed = std::strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed < 1 || parsed > maximum)
        return false;
    value = static_cast<int>(parsed);
    return true;
}

double calc_gflops(int N, double time_ms) {
    if (time_ms <= 0.0) return 0.0;
    return (5.0 * static_cast<double>(N) * std::log2(static_cast<double>(N))) /
           (time_ms * 1e6);
}

// Deterministic generator independent of rand()/srand() global state.
// One input vector is generated in main and passed to every implementation.
std::vector<cpxcuda> make_input(int N) {
    std::vector<cpxcuda> data(N);
    uint64_t state = INPUT_SEED;
    auto next_unit = [&state]() {
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        const uint64_t mantissa = state >> 11; // 53 useful bits
        return static_cast<double>(mantissa) * (1.0 / 9007199254740992.0);
    };

    for (int i = 0; i < N; ++i) {
        data[i].re = 2.0 * next_unit() - 1.0;
        data[i].im = 2.0 * next_unit() - 1.0;
    }
    return data;
}

std::string read_cpu_model() {
    std::ifstream in("/proc/cpuinfo");
    std::string line;
    while (std::getline(in, line)) {
        const std::string key = "model name";
        if (line.compare(0, key.size(), key) == 0) {
            const auto pos = line.find(':');
            if (pos != std::string::npos) {
                std::string model = line.substr(pos + 1);
                const auto first = model.find_first_not_of(" \t");
                if (first != std::string::npos) model.erase(0, first);
                return model;
            }
        }
    }
    return "unknown";
}

std::string cuda_version_string(int version) {
    if (version <= 0) return "unknown";
    std::ostringstream oss;
    oss << (version / 1000) << '.' << ((version % 1000) / 10);
    return oss.str();
}

// ================= Correctness check =================
double verify_accuracy(const std::vector<cpxcuda> &input,
                       const cpxcuda *my_result) {
    const int N = static_cast<int>(input.size());
    const size_t bytes = sizeof(cufftDoubleComplex) * static_cast<size_t>(N);

    cufftDoubleComplex *d_data = nullptr;
    cufftDoubleComplex *h_ref = nullptr;
    CUDA_CHECK(cudaMalloc(&d_data, bytes));
    h_ref = static_cast<cufftDoubleComplex*>(std::malloc(bytes));
    if (!h_ref) {
        std::fprintf(stderr, "Host allocation failed during verification.\n");
        std::exit(EXIT_FAILURE);
    }

    CUDA_CHECK(cudaMemcpy(d_data, input.data(), bytes, cudaMemcpyHostToDevice));

    cufftHandle plan;
    CUFFT_CHECK(cufftPlan1d(&plan, N, CUFFT_Z2Z, 1));
    CUFFT_CHECK(cufftExecZ2Z(plan, d_data, d_data, CUFFT_FORWARD));
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(h_ref, d_data, bytes, cudaMemcpyDeviceToHost));

    double max_err = 0.0;
    for (int i = 0; i < N; ++i) {
        const double diff_re = my_result[i].re - h_ref[i].x;
        const double diff_im = my_result[i].im - h_ref[i].y;
        const double err = std::hypot(diff_re, diff_im);
        if (!std::isfinite(err)) {
            max_err = INFINITY;
            break;
        }
        max_err = std::max(max_err, err);
    }

    CUFFT_CHECK(cufftDestroy(plan));
    CUDA_CHECK(cudaFree(d_data));
    std::free(h_ref);
    return max_err;
}

// ================= FFTW baseline =================
double benchmark_fftw(const std::vector<cpxcuda> &input, int threads) {
    const int N = static_cast<int>(input.size());
    fftw_complex *in = static_cast<fftw_complex*>(fftw_malloc(sizeof(fftw_complex) * N));
    fftw_complex *out = static_cast<fftw_complex*>(fftw_malloc(sizeof(fftw_complex) * N));
    if (!in || !out) {
        std::fprintf(stderr, "FFTW allocation failed for N=%d\n", N);
        std::exit(EXIT_FAILURE);
    }

    // Planning is intentionally outside the timed region. FFTW_MEASURE is used
    // so the public CPU baseline is an optimized FFTW execution plan rather than
    // an estimate-only plan.
    fftw_plan_with_nthreads(threads);
    fftw_plan p = fftw_plan_dft_1d(N, in, out, FFTW_FORWARD, FFTW_MEASURE);
    if (!p) {
        std::fprintf(stderr, "FFTW planning failed for N=%d, threads=%d\n", N, threads);
        std::exit(EXIT_FAILURE);
    }

    // FFTW_MEASURE may overwrite planning buffers; restore the exact shared input.
    for (int i = 0; i < N; ++i) {
        in[i][0] = input[i].re;
        in[i][1] = input[i].im;
    }

    for (int i = 0; i < WARMUP; ++i) fftw_execute(p);

    const auto start = std::chrono::steady_clock::now();
    for (int i = 0; i < REPEAT; ++i) fftw_execute(p);
    const auto stop = std::chrono::steady_clock::now();

    const double total_ms =
        std::chrono::duration<double, std::milli>(stop - start).count();

    fftw_destroy_plan(p);
    fftw_free(in);
    fftw_free(out);
    return total_ms / REPEAT;
}

// ================= cuFFT baseline =================
struct CufftMetrics {
    double device_ms = 0.0;
    double e2e_ms = 0.0;
    double gflops = 0.0;
};

CufftMetrics benchmark_cufft(const std::vector<cpxcuda> &input) {
    const int N = static_cast<int>(input.size());
    const size_t bytes = sizeof(cufftDoubleComplex) * static_cast<size_t>(N);

    cpxcuda *h_in = nullptr;
    cpxcuda *h_out = nullptr;
    cufftDoubleComplex *d_data = nullptr;
    cudaStream_t stream;
    cufftHandle plan;

    CUDA_CHECK(cudaMallocHost(&h_in, bytes));
    CUDA_CHECK(cudaMallocHost(&h_out, bytes));
    std::memcpy(h_in, input.data(), bytes);
    CUDA_CHECK(cudaMalloc(&d_data, bytes));
    CUDA_CHECK(cudaStreamCreate(&stream));
    CUFFT_CHECK(cufftPlan1d(&plan, N, CUFFT_Z2Z, 1));
    CUFFT_CHECK(cufftSetStream(plan, stream));

    // In-place cuFFT is used to match the custom GPU FFT interface more closely.
    // Input is restored before every transform; the restore is outside the
    // device-execution event interval.
    for (int i = 0; i < WARMUP; ++i) {
        CUDA_CHECK(cudaMemcpyAsync(d_data, h_in, bytes, cudaMemcpyHostToDevice, stream));
        CUFFT_CHECK(cufftExecZ2Z(plan, d_data, d_data, CUFFT_FORWARD));
    }
    CUDA_CHECK(cudaStreamSynchronize(stream));

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    double device_sum_ms = 0.0;
    for (int i = 0; i < REPEAT; ++i) {
        CUDA_CHECK(cudaMemcpyAsync(d_data, h_in, bytes, cudaMemcpyHostToDevice, stream));
        CUDA_CHECK(cudaEventRecord(start, stream));
        CUFFT_CHECK(cufftExecZ2Z(plan, d_data, d_data, CUFFT_FORWARD));
        CUDA_CHECK(cudaEventRecord(stop, stream));
        CUDA_CHECK(cudaEventSynchronize(stop));

        float elapsed_ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        device_sum_ms += elapsed_ms;
    }

    auto execute_e2e = [&]() {
        CUDA_CHECK(cudaMemcpyAsync(d_data, h_in, bytes, cudaMemcpyHostToDevice, stream));
        CUFFT_CHECK(cufftExecZ2Z(plan, d_data, d_data, CUFFT_FORWARD));
        CUDA_CHECK(cudaMemcpyAsync(h_out, d_data, bytes, cudaMemcpyDeviceToHost, stream));
        CUDA_CHECK(cudaStreamSynchronize(stream));
    };

    for (int i = 0; i < WARMUP; ++i) execute_e2e();

    double e2e_sum_ms = 0.0;
    for (int i = 0; i < REPEAT; ++i) {
        const auto begin = std::chrono::steady_clock::now();
        execute_e2e();
        const auto end = std::chrono::steady_clock::now();
        e2e_sum_ms +=
            std::chrono::duration<double, std::milli>(end - begin).count();
    }

    CufftMetrics metrics;
    metrics.device_ms = device_sum_ms / REPEAT;
    metrics.e2e_ms = e2e_sum_ms / REPEAT;
    metrics.gflops = calc_gflops(N, metrics.device_ms);

    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUFFT_CHECK(cufftDestroy(plan));
    CUDA_CHECK(cudaStreamDestroy(stream));
    CUDA_CHECK(cudaFree(d_data));
    CUDA_CHECK(cudaFreeHost(h_in));
    CUDA_CHECK(cudaFreeHost(h_out));
    return metrics;
}

// ================= Custom CUDA FFT =================
struct MyCudaMetrics {
    double h2d_ms = 0.0;
    double device_ms = 0.0;
    double d2h_ms = 0.0;
    double component_sum_ms = 0.0;
    double e2e_ms = 0.0;
    double gflops = 0.0;
    double error = 0.0;
};

MyCudaMetrics benchmark_my_cuda(const std::vector<cpxcuda> &input) {
    const int N = static_cast<int>(input.size());
    const size_t bytes = sizeof(cpxcuda) * static_cast<size_t>(N);

    cpxcuda *h_in = nullptr;
    cpxcuda *h_out = nullptr;
    CUDA_CHECK(cudaMallocHost(&h_in, bytes));
    CUDA_CHECK(cudaMallocHost(&h_out, bytes));
    std::memcpy(h_in, input.data(), bytes);

    fft_plan_cuda plan = fft_plan_cuda_1d(N, 1, h_in, h_out, false);
    cudaStream_t stream;
    CUDA_CHECK(cudaStreamCreate(&stream));

    auto execute_e2e = [&]() {
        CUDA_CHECK(cudaMemcpyAsync(plan.out_device, h_in, bytes,
                                   cudaMemcpyHostToDevice, stream));
        fft_execute_plan_cuda_async(plan, stream);
        CUDA_CHECK(cudaMemcpyAsync(h_out, plan.out_device, bytes,
                                   cudaMemcpyDeviceToHost, stream));
        CUDA_CHECK(cudaStreamSynchronize(stream));
    };

    for (int i = 0; i < WARMUP; ++i) execute_e2e();

    // One run produces all three component timings. Part 2 later reuses these
    // stored values instead of re-running the benchmark and creating conflicting
    // numbers for the same N.
    cudaEvent_t events[4];
    for (auto &event : events) CUDA_CHECK(cudaEventCreate(&event));

    MyCudaMetrics m;
    for (int i = 0; i < REPEAT; ++i) {
        CUDA_CHECK(cudaEventRecord(events[0], stream));
        CUDA_CHECK(cudaMemcpyAsync(plan.out_device, h_in, bytes,
                                   cudaMemcpyHostToDevice, stream));
        CUDA_CHECK(cudaEventRecord(events[1], stream));

        fft_execute_plan_cuda_async(plan, stream);
        CUDA_CHECK(cudaEventRecord(events[2], stream));

        CUDA_CHECK(cudaMemcpyAsync(h_out, plan.out_device, bytes,
                                   cudaMemcpyDeviceToHost, stream));
        CUDA_CHECK(cudaEventRecord(events[3], stream));
        CUDA_CHECK(cudaEventSynchronize(events[3]));

        float h2d = 0.0f, device = 0.0f, d2h = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&h2d, events[0], events[1]));
        CUDA_CHECK(cudaEventElapsedTime(&device, events[1], events[2]));
        CUDA_CHECK(cudaEventElapsedTime(&d2h, events[2], events[3]));
        m.h2d_ms += h2d;
        m.device_ms += device;
        m.d2h_ms += d2h;
    }

    m.h2d_ms /= REPEAT;
    m.device_ms /= REPEAT;
    m.d2h_ms /= REPEAT;
    m.component_sum_ms = m.h2d_ms + m.device_ms + m.d2h_ms;

    // Independent E2E samples: no timing events inside the measured region.
    for (int i = 0; i < WARMUP; ++i) execute_e2e();

    double e2e_sum_ms = 0.0;
    for (int i = 0; i < REPEAT; ++i) {
        const auto start = std::chrono::steady_clock::now();
        execute_e2e();
        const auto stop = std::chrono::steady_clock::now();
        e2e_sum_ms +=
            std::chrono::duration<double, std::milli>(stop - start).count();
    }
    m.e2e_ms = e2e_sum_ms / REPEAT;
    m.gflops = calc_gflops(N, m.device_ms);

    // execute_e2e() leaves h_out populated with the transform of the shared input.
    m.error = verify_accuracy(input, h_out);
    if (!std::isfinite(m.error) || m.error > ACCURACY_TOLERANCE) {
        std::fprintf(stderr,
                     "Accuracy check FAILED at N=%d: max error %.6e > %.1e\n",
                     N, m.error, ACCURACY_TOLERANCE);
        std::exit(EXIT_FAILURE);
    }

    for (auto event : events) CUDA_CHECK(cudaEventDestroy(event));
    CUDA_CHECK(cudaStreamDestroy(stream));
    fft_destroy_plan_cuda(plan);
    CUDA_CHECK(cudaFreeHost(h_in));
    CUDA_CHECK(cudaFreeHost(h_out));
    return m;
}

// ================= Result row / CSV =================
struct ResultRow {
    int N = 0;
    int log2N = 0;
    double fftw_1t_ms = 0.0;
    double fftw_mt_ms = 0.0;
    MyCudaMetrics my;
    CufftMetrics cufft;
};

double safe_ratio(double numerator, double denominator) {
    return denominator > 0.0 ? numerator / denominator : 0.0;
}

void write_csv(const std::string &path, const std::vector<ResultRow> &rows,
               int fftw_threads) {
    std::ofstream out(path);
    if (!out) {
        std::fprintf(stderr, "Failed to open CSV output: %s\n", path.c_str());
        std::exit(EXIT_FAILURE);
    }

    out << "N,log2N,fftw_1t_ms,fftw_mt_threads,fftw_mt_ms,fftw_st_mt_speedup,"
        << "mycuda_h2d_ms,mycuda_device_ms,mycuda_d2h_ms,mycuda_component_sum_ms,"
        << "mycuda_e2e_ms,cufft_device_ms,cufft_e2e_ms,mycuda_gflops,cufft_gflops,"
        << "max_abs_error,mycuda_device_speedup_vs_fftw_1t,"
        << "mycuda_device_speedup_vs_fftw_mt,mycuda_e2e_speedup_vs_fftw_1t,"
        << "mycuda_e2e_speedup_vs_fftw_mt,mycuda_vs_cufft_device_pct,"
        << "mycuda_vs_cufft_e2e_pct\n";

    out << std::setprecision(10);
    for (const auto &r : rows) {
        out << r.N << ',' << r.log2N << ','
            << r.fftw_1t_ms << ',' << fftw_threads << ',' << r.fftw_mt_ms << ','
            << safe_ratio(r.fftw_1t_ms, r.fftw_mt_ms) << ','
            << r.my.h2d_ms << ',' << r.my.device_ms << ',' << r.my.d2h_ms << ','
            << r.my.component_sum_ms << ',' << r.my.e2e_ms << ','
            << r.cufft.device_ms << ',' << r.cufft.e2e_ms << ','
            << r.my.gflops << ',' << r.cufft.gflops << ',' << r.my.error << ','
            << safe_ratio(r.fftw_1t_ms, r.my.device_ms) << ','
            << safe_ratio(r.fftw_mt_ms, r.my.device_ms) << ','
            << safe_ratio(r.fftw_1t_ms, r.my.e2e_ms) << ','
            << safe_ratio(r.fftw_mt_ms, r.my.e2e_ms) << ','
            << 100.0 * safe_ratio(r.cufft.device_ms, r.my.device_ms) << ','
            << 100.0 * safe_ratio(r.cufft.e2e_ms, r.my.e2e_ms)
            << '\n';
    }
}

void write_metadata(const std::string &path, int fftw_threads) {
    cudaDeviceProp prop{};
    int device = 0;
    int runtime_version = 0;
    int driver_version = 0;
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));
    CUDA_CHECK(cudaRuntimeGetVersion(&runtime_version));
    CUDA_CHECK(cudaDriverGetVersion(&driver_version));

    std::ofstream out(path);
    if (!out) {
        std::fprintf(stderr, "Failed to open metadata output: %s\n", path.c_str());
        std::exit(EXIT_FAILURE);
    }

    out << "GPU: " << prop.name << '\n';
    out << "GPU compute capability: " << prop.major << '.' << prop.minor << '\n';
    out << "CPU: " << read_cpu_model() << '\n';
    out << "CUDA runtime: " << cuda_version_string(runtime_version) << '\n';
    out << "CUDA driver API version: " << cuda_version_string(driver_version) << '\n';
    out << "FFTW version: " << fftw_version << '\n';
    out << "FFTW multi-thread setting: " << fftw_threads << '\n';
    out << "Precision: double complex (FP64)\n";
    out << "Direction: forward\n";
    out << "Batch size: 1\n";
    out << "Warmup: " << WARMUP << '\n';
    out << "Repeats: " << REPEAT << '\n';
    out << "FFTW planner: FFTW_MEASURE\n";
    out << "Accuracy tolerance: " << std::scientific << ACCURACY_TOLERANCE << '\n';
}

// ================= Main =================
int main(int argc, char **argv) {
    int fftw_threads = DEFAULT_FFTW_THREADS;
    std::string csv_path = "benchmark_results.csv";

    for (int arg = 1; arg < argc; ++arg) {
        if (std::strcmp(argv[arg], "--fftw-threads") == 0 && arg + 1 < argc &&
            parse_positive_int(argv[arg + 1], 1024, fftw_threads)) {
            ++arg;
        } else if (std::strcmp(argv[arg], "--csv") == 0 && arg + 1 < argc) {
            csv_path = argv[++arg];
        } else {
            std::fprintf(stderr,
                         "Usage: %s [--fftw-threads 1..1024] [--csv output.csv]\n",
                         argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (!fftw_init_threads()) {
        std::fprintf(stderr, "FFTW thread initialization failed.\n");
        return EXIT_FAILURE;
    }

    cudaDeviceProp prop{};
    int device = 0;
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));

    std::printf("\n");
    std::printf("===============================================================================\n");
    std::printf(" CUDA FFT PORTFOLIO BENCHMARK\n");
    std::printf("===============================================================================\n");
    std::printf("GPU: %s (compute capability %d.%d)\n", prop.name, prop.major, prop.minor);
    std::printf("CPU: %s\n", read_cpu_model().c_str());
    std::printf("FFTW: 1 thread and %d threads, FFTW_MEASURE, execution only.\n", fftw_threads);
    std::printf("MyCUDA/cuFFT: FP64 complex forward FFT, batch=1.\n");
    std::printf("Warmup=%d, repeats=%d. Planning/allocation excluded.\n", WARMUP, REPEAT);
    std::printf("MyCUDA component timing: CUDA events for H2D / device / D2H.\n");
    std::printf("E2E: host wall clock for H2D -> FFT -> D2H -> stream sync.\n");
    std::printf("Accuracy: max absolute complex error vs cuFFT, tolerance %.1e.\n",
                ACCURACY_TOLERANCE);
    std::printf("CSV: %s\n\n", csv_path.c_str());

    std::vector<ResultRow> rows;
    rows.reserve(MAX_LOG_N - MIN_LOG_N + 1);

    std::printf("%-10s %-6s %-12s %-12s %-12s %-12s %-12s %-12s %-10s\n",
                "N", "log2N", "FFTW_1T", "FFTW_MT", "MyCUDA_dev",
                "cuFFT_dev", "MyCUDA_E2E", "cuFFT_E2E", "Error");
    std::printf("-----------------------------------------------------------------------------------------------\n");

    for (int logN = MIN_LOG_N; logN <= MAX_LOG_N; ++logN) {
        const int N = 1 << logN;
        const std::vector<cpxcuda> input = make_input(N);

        ResultRow row;
        row.N = N;
        row.log2N = logN;
        row.fftw_1t_ms = benchmark_fftw(input, 1);
        row.fftw_mt_ms = benchmark_fftw(input, fftw_threads);
        row.cufft = benchmark_cufft(input);
        row.my = benchmark_my_cuda(input);
        rows.push_back(row);

        std::printf("%-10d %-6d %-12.4f %-12.4f %-12.4f %-12.4f %-12.4f %-12.4f %-10.2e\n",
                    row.N, row.log2N, row.fftw_1t_ms, row.fftw_mt_ms,
                    row.my.device_ms, row.cufft.device_ms,
                    row.my.e2e_ms, row.cufft.e2e_ms, row.my.error);
    }

    write_csv(csv_path, rows, fftw_threads);
    write_metadata("benchmark_metadata.txt", fftw_threads);

    // Reuse the exact Part 1 measurements for the two breakdown rows.
    std::printf("\nTIME BREAKDOWN (same measurements as the main table)\n");
    std::printf("%-12s %-10s %-12s %-10s %-14s %-10s %-10s %-10s\n",
                "Size", "H2D(ms)", "Device(ms)", "D2H(ms)", "Component(ms)",
                "H2D%", "Device%", "D2H%");
    std::printf("----------------------------------------------------------------------------------------\n");

    for (const auto &r : rows) {
        if (r.N != 1024 && r.N != 1048576) continue;
        const double total = r.my.component_sum_ms;
        std::printf("N=2^%-7d %-10.4f %-12.4f %-10.4f %-14.4f %-9.1f%% %-9.1f%% %-9.1f%%\n",
                    r.log2N,
                    r.my.h2d_ms, r.my.device_ms, r.my.d2h_ms, total,
                    100.0 * safe_ratio(r.my.h2d_ms, total),
                    100.0 * safe_ratio(r.my.device_ms, total),
                    100.0 * safe_ratio(r.my.d2h_ms, total));
    }

    // Portfolio headline summary at N=2^20.
    const auto it = std::find_if(rows.begin(), rows.end(), [](const ResultRow &r) {
        return r.N == 1048576;
    });
    if (it != rows.end()) {
        const ResultRow &r = *it;
        std::printf("\nN=2^20 PORTFOLIO SUMMARY\n");
        std::printf("  FFTW 1T execution:              %.4f ms\n", r.fftw_1t_ms);
        std::printf("  FFTW %dT execution:              %.4f ms\n", fftw_threads, r.fftw_mt_ms);
        std::printf("  MyCUDA device execution:        %.4f ms\n", r.my.device_ms);
        std::printf("  MyCUDA E2E:                     %.4f ms\n", r.my.e2e_ms);
        std::printf("  cuFFT device execution:         %.4f ms\n", r.cufft.device_ms);
        std::printf("  cuFFT E2E:                      %.4f ms\n", r.cufft.e2e_ms);
        std::printf("  Device speedup vs FFTW 1T:      %.2fx\n",
                    safe_ratio(r.fftw_1t_ms, r.my.device_ms));
        std::printf("  Device speedup vs FFTW %dT:      %.2fx\n", fftw_threads,
                    safe_ratio(r.fftw_mt_ms, r.my.device_ms));
        std::printf("  E2E speedup vs FFTW 1T:         %.2fx\n",
                    safe_ratio(r.fftw_1t_ms, r.my.e2e_ms));
        std::printf("  E2E speedup vs FFTW %dT:         %.2fx\n", fftw_threads,
                    safe_ratio(r.fftw_mt_ms, r.my.e2e_ms));
        std::printf("  MyCUDA / cuFFT device perf.:    %.1f%%\n",
                    100.0 * safe_ratio(r.cufft.device_ms, r.my.device_ms));
        std::printf("  MyCUDA / cuFFT E2E perf.:       %.1f%%\n",
                    100.0 * safe_ratio(r.cufft.e2e_ms, r.my.e2e_ms));
        std::printf("  Max absolute error vs cuFFT:    %.3e\n", r.my.error);
    }

    std::printf("\nSaved: %s\n", csv_path.c_str());
    std::printf("Saved: benchmark_metadata.txt\n");
    std::printf("Benchmark completed successfully.\n");

    fftw_cleanup_threads();
    return 0;
}
