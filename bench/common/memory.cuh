#pragma once
#include "runtime.cuh"
#include <cstdint>

namespace measure {
// Explicit .cg vector instructions keep the in-place identity copy observable
// and bypass L1, so the resident curve measures L2 rather than L1 bandwidth.
// A plain p[i] = p[i] would be removed by the compiler.
__device__ inline double2 load16(const double2* pointer) {
    double2 value;
    asm volatile("ld.global.cg.v2.f64 {%0, %1}, [%2];" : "=d"(value.x), "=d"(value.y) : "l"(pointer) : "memory");
    return value;
}
__device__ inline void store16(double2* pointer, double2 value) {
    asm volatile("st.global.cg.v2.f64 [%0], {%1, %2};" :: "l"(pointer), "d"(value.x), "d"(value.y) : "memory");
}
__global__ void copy16(const double2* source, double2* dest, size_t count, int passes = 1) {
    for (int pass = 0; pass < passes; ++pass)
        for (size_t i = size_t(blockIdx.x) * blockDim.x + threadIdx.x; i < count;
             i += size_t(blockDim.x) * gridDim.x) store16(dest + i, load16(source + i));
}
__global__ void write16(double2* dest, size_t count, double value) {
    for (size_t i = size_t(blockIdx.x) * blockDim.x + threadIdx.x; i < count;
         i += size_t(blockDim.x) * gridDim.x) store16(dest + i, make_double2(value, -value));
}
__global__ void read16(const double2* source, size_t count, double2* sink, int passes = 1) {
    double2 sum = make_double2(0, 0);
    for (int pass = 0; pass < passes; ++pass)
        for (size_t i = size_t(blockIdx.x) * blockDim.x + threadIdx.x; i < count;
             i += size_t(blockDim.x) * gridDim.x) {
            const double2 value = load16(source + i); sum.x += value.x; sum.y += value.y;
        }
    for (int delta = 16; delta; delta /= 2) {
        sum.x += __shfl_down_sync(0xffffffff, sum.x, delta);
        sum.y += __shfl_down_sync(0xffffffff, sum.y, delta);
    }
    __shared__ double2 warp_sums[32];
    if ((threadIdx.x & 31) == 0) warp_sums[threadIdx.x / 32] = sum;
    __syncthreads();
    if (threadIdx.x == 0) {
        double2 total = make_double2(0, 0);
        for (unsigned int w = 0; w < blockDim.x / 32; ++w) {
            total.x += warp_sums[w].x; total.y += warp_sums[w].y;
        }
        store16(sink + blockIdx.x, total);
    }
}
class L2Flush {
    DeviceBuffer<double2> buffer_;
    size_t count_;
    int blocks_;
public:
    L2Flush() : buffer_(), count_((2 * l2_bytes() + 15) / 16),
                blocks_(device_properties().multiProcessorCount * 8) { buffer_.allocate(count_); }
    void operator()(cudaStream_t stream) {
        write16<<<blocks_, 256, 0, stream>>>(buffer_.get(), count_, 1.0);
        T1_CUDA(cudaGetLastError());
    }
};
__device__ inline uint64_t mix64(uint64_t x) {
    x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
    return x ^ (x >> 31);
}
__global__ void seeded_input(cuDoubleComplex* data, size_t count, uint64_t seed) {
    for (size_t i = size_t(blockIdx.x) * blockDim.x + threadIdx.x; i < count;
         i += size_t(blockDim.x) * gridDim.x) {
        const uint64_t a = mix64(seed + 2 * uint64_t(i)), b = mix64(seed + 2 * uint64_t(i) + 1);
        data[i] = make_cuDoubleComplex(2.0 * double(a >> 11) * 0x1.0p-53 - 1.0,
                                     2.0 * double(b >> 11) * 0x1.0p-53 - 1.0);
    }
}
inline void fill_input(cuDoubleComplex* data, size_t count, cudaStream_t stream, uint64_t seed = 12345) {
    seeded_input<<<device_properties().multiProcessorCount * 4, 256, 0, stream>>>(data, count, seed);
    T1_CUDA(cudaGetLastError());
}
} // namespace measure
