// Optional diagnostic utility, separate from the normal benchmark executable.
// Build: make profile_stages CUDA_ARCH=sm_80
// Run: ./profile_stages
// Includes the implementation to inspect private kernel attributes and record
// stage events. Compile alone: do not also link fft_cuda.o.
// Event intervals are diagnostic, not interchangeable with normal device time.
// The bitwise check compares instrumented/uninstrumented execution of the same
// current implementation; benchmark.cpp provides the independent cuFFT check.
#include "fft_cuda.cu"
#include <cstring>
#include <vector>

int main() {
    const int n = 1 << 20;
    const int warmup = 10;
    const int repeats = 100;
    const size_t bytes = (size_t)n * sizeof(cpxcuda);

    cpxcuda *input, *output;
    CUDA_CHECK(cudaMallocHost(&input, bytes));
    CUDA_CHECK(cudaMallocHost(&output, bytes));
    std::srand(12345);
    for (int i = 0; i < n; ++i) {
        input[i].re = 2.0 * std::rand() / RAND_MAX - 1.0;
        input[i].im = 2.0 * std::rand() / RAND_MAX - 1.0;
    }

    fft_plan_cuda plan = fft_plan_cuda_1d(n, 1, input, output, false);
    cudaStream_t stream;
    CUDA_CHECK(cudaStreamCreate(&stream));
    cudaEvent_t events[6];
    for (auto &event : events) CUDA_CHECK(cudaEventCreate(&event));

    cudaFuncAttributes attr;
    CUDA_CHECK(cudaFuncGetAttributes(&attr, fft_block_1024_specialized));
    std::printf("fft_block_1024_specialized: registers/thread=%d, static shared=%zu bytes, "
                "dynamic shared/launch=0 bytes, local/thread=%zu bytes\n",
                attr.numRegs, attr.sharedSizeBytes, attr.localSizeBytes);
    std::printf("Spill stores/loads: see PTXAS build output for this kernel.\n");

    auto restore_input = [&]() {
        // Same-stream ordering excludes this copy from subsequent event timing.
        CUDA_CHECK(cudaMemcpyAsync(plan.out_device, input, bytes,
                                   cudaMemcpyHostToDevice, stream));
    };

    auto execute = [&](const cudaEvent_t *markers) {
        const bool needs_copy = fft_1d_fourstep_opt<256>(
            plan.out_device, plan.temp_device, plan.ws_device,
            plan.n, plan.R, plan.C, plan.reverse, stream, markers);
        // This profiler deliberately covers the five-stage square path only.
        if (needs_copy) {
            std::fprintf(stderr, "Unexpected path: final D2D is required.\n");
            std::exit(EXIT_FAILURE);
        }
        CUDA_CHECK(cudaGetLastError());
    };

    double stage_sum[5] = {};
    double total_sum[2] = {};
    std::vector<cpxcuda> reference(n);

    // Pass 0: only start/stop events. Pass 1: all stage boundaries.
    for (int pass = 0; pass < 2; ++pass) {
        const bool instrumented = pass == 1;
        for (int rep = -warmup; rep < repeats; ++rep) {
            restore_input();
            if (instrumented) {
                execute(events);
            } else {
                CUDA_CHECK(cudaEventRecord(events[0], stream));
                execute(nullptr);
                CUDA_CHECK(cudaEventRecord(events[5], stream));
            }
            // No synchronization between individual kernels.
            CUDA_CHECK(cudaEventSynchronize(events[5]));
            if (rep < 0) continue;

            float elapsed;
            CUDA_CHECK(cudaEventElapsedTime(&elapsed, events[0], events[5]));
            total_sum[pass] += elapsed;
            if (instrumented) {
                for (int stage = 0; stage < 5; ++stage) {
                    CUDA_CHECK(cudaEventElapsedTime(
                        &elapsed, events[stage], events[stage + 1]));
                    stage_sum[stage] += elapsed;
                }
            }
        }

        // Output comparison is outside every timed interval.
        CUDA_CHECK(cudaMemcpyAsync(output, plan.out_device, bytes,
                                   cudaMemcpyDeviceToHost, stream));
        CUDA_CHECK(cudaStreamSynchronize(stream));
        for (int i = 0; i < n; ++i) {
            if (!std::isfinite(output[i].re) || !std::isfinite(output[i].im)) {
                std::fprintf(stderr, "Non-finite output at index %d\n", i);
                std::exit(EXIT_FAILURE);
            }
        }
        if (!instrumented) {
            std::memcpy(reference.data(), output, bytes);
        } else if (std::memcmp(reference.data(), output, bytes) != 0) {
            std::fprintf(stderr, "Instrumented output differs from baseline.\n");
            std::exit(EXIT_FAILURE);
        }
    }

    const char *names[5] = {
        "transpose_opt",
        "first fft_block_1024_specialized",
        "transpose_and_twiddle",
        "second fft_block_1024_specialized",
        "transpose_square_inplace"
    };
    std::printf("\nN=%d, batch=1, forward, warmup=%d/pass, repeats=%d/pass\n",
                n, warmup, repeats);
    std::printf("Stage intervals exclude H2D/D2H; include event timing effects.\n");
    std::printf("%-38s %12s %18s\n",
                "Stage", "Mean (ms)", "% profiled total");
    double stage_total = 0.0;
    for (int stage = 0; stage < 5; ++stage) {
        stage_total += stage_sum[stage];
        const double percent = total_sum[1] > 0.0
            ? 100.0 * stage_sum[stage] / total_sum[1] : 0.0;
        std::printf("%-38s %12.6f %17.2f%%\n",
                    names[stage], stage_sum[stage] / repeats, percent);
    }
    std::printf("Sum of stage means:       %.6f ms\n", stage_total / repeats);
    std::printf("Instrumented total mean:  %.6f ms\n", total_sum[1] / repeats);
    std::printf("Start/stop-only total:    %.6f ms\n", total_sum[0] / repeats);
    std::printf("Difference between runs: %+.6f ms (includes run variability)\n",
                (total_sum[1] - total_sum[0]) / repeats);
    std::printf("Instrumented/uninstrumented output: bitwise identical.\n");

    for (auto event : events) CUDA_CHECK(cudaEventDestroy(event));
    CUDA_CHECK(cudaStreamDestroy(stream));
    fft_destroy_plan_cuda(plan);
    CUDA_CHECK(cudaFreeHost(input));
    CUDA_CHECK(cudaFreeHost(output));
    return 0;
}
