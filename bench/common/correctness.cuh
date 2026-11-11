#pragma once
#include "memory.cuh"
#ifdef T1_WITH_FFTW
#include <fftw3.h>
#endif

namespace measure {
struct ErrorSums { double diff2, ref2, max_abs; int nonfinite; };
__global__ void error_sums(const cuDoubleComplex* actual, const cuDoubleComplex* reference,
                          size_t count, ErrorSums* out) {
    double ds = 0, rs = 0, maximum = 0;
    int nonfinite = 0;
    for (size_t i = size_t(blockIdx.x) * blockDim.x + threadIdx.x; i < count;
         i += size_t(gridDim.x) * blockDim.x) {
        const auto a = actual[i], r = reference[i];
        const double re = a.x - r.x, im = a.y - r.y;
        ds += re * re + im * im; rs += r.x * r.x + r.y * r.y;
        maximum = fmax(maximum, hypot(re, im));
        if (!isfinite(a.x) || !isfinite(a.y) || !isfinite(r.x) || !isfinite(r.y)) nonfinite = 1;
    }
    __shared__ ErrorSums shared[256];
    shared[threadIdx.x] = {ds, rs, maximum, nonfinite};
    __syncthreads();
    for (unsigned int stride = blockDim.x / 2; stride; stride /= 2) {
        if (threadIdx.x < stride) {
            auto& a = shared[threadIdx.x]; const auto b = shared[threadIdx.x + stride];
            a.diff2 += b.diff2; a.ref2 += b.ref2;
            a.max_abs = fmax(a.max_abs, b.max_abs); a.nonfinite |= b.nonfinite;
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) out[blockIdx.x] = shared[0];
}
struct Errors { double relative_l2, maximum; };
inline Errors compare(const cuDoubleComplex* actual, const cuDoubleComplex* reference, size_t count,
                      cudaStream_t stream) {
    const int blocks = 1024;
    DeviceBuffer<ErrorSums> device(blocks);
    error_sums<<<blocks, 256, 0, stream>>>(actual, reference, count, device.get());
    T1_CUDA(cudaGetLastError());
    std::vector<ErrorSums> host(blocks);
    T1_CUDA(cudaMemcpyAsync(host.data(), device.get(), host.size() * sizeof(ErrorSums), cudaMemcpyDeviceToHost, stream));
    T1_CUDA(cudaStreamSynchronize(stream));
    long double ds = 0, rs = 0;
    double maximum = 0;
    bool nonfinite = false;
    for (const auto& row : host) {
        ds += row.diff2; rs += row.ref2; maximum = std::max(maximum, row.max_abs);
        nonfinite = nonfinite || row.nonfinite;
    }
    if (nonfinite || !std::isfinite(ds) || !std::isfinite(rs) || rs <= 0)
        return {std::numeric_limits<double>::infinity(), std::numeric_limits<double>::infinity()};
    return {double(std::sqrt(ds / rs)), maximum};
}
class Reference {
    cufftHandle plan_ = 0;
    DeviceBuffer<cuDoubleComplex> output_;
public:
    Reference(size_t n, int batch) : output_(elements(n, batch)) {
        int dims[] = {int(n)};
        T1_CUFFT(cufftPlanMany(&plan_, 1, dims, dims, 1, int(n), dims, 1, int(n), CUFFT_Z2Z, batch));
    }
    ~Reference() { if (plan_) cufftDestroy(plan_); }
    cuDoubleComplex* run(cuDoubleComplex* input, cudaStream_t stream) {
        T1_CUFFT(cufftSetStream(plan_, stream));
        // Explicit distinct pointers: correctness reference is out of place.
        T1_CUFFT(cufftExecZ2Z(plan_, input, output_.get(), CUFFT_FORWARD));
        return output_.get();
    }
};
inline Errors verify_fftw(cuDoubleComplex* input, cuDoubleComplex* reference, size_t n, cudaStream_t stream) {
#ifdef T1_WITH_FFTW
    std::vector<cuDoubleComplex> host(n), ref(n), result(n);
    T1_CUDA(cudaMemcpyAsync(host.data(), input, n * sizeof(cuDoubleComplex), cudaMemcpyDeviceToHost, stream));
    T1_CUDA(cudaMemcpyAsync(ref.data(), reference, n * sizeof(cuDoubleComplex), cudaMemcpyDeviceToHost, stream));
    T1_CUDA(cudaStreamSynchronize(stream));
    fftw_plan plan = fftw_plan_dft_1d(int(n), reinterpret_cast<fftw_complex*>(host.data()),
                                    reinterpret_cast<fftw_complex*>(result.data()), FFTW_FORWARD, FFTW_ESTIMATE);
    if (!plan) throw std::runtime_error("FFTW_ESTIMATE planning failed");
    fftw_execute(plan); fftw_destroy_plan(plan);
    long double ds = 0, rs = 0;
    double maximum = 0;
    for (size_t i = 0; i < n; ++i) {
        const long double re = result[i].x - ref[i].x, im = result[i].y - ref[i].y;
        ds += re * re + im * im;
        rs += static_cast<long double>(result[i].x) * result[i].x + static_cast<long double>(result[i].y) * result[i].y;
        maximum = std::max(maximum, double(std::hypot(re, im)));
    }
    return {double(std::sqrt(ds / rs)), maximum};
#else
    (void)input; (void)reference; (void)n; (void)stream;
    throw std::runtime_error("--verify-fftw requires rebuilding bench with WITH_FFTW=1 (libfftw3-dev)");
#endif
}
} // namespace measure
