/*
 * Double-precision mixed-radix CUDA FFT used by benchmark.cpp.
 * Large forward pipeline:
 * transpose -> row FFT -> transpose+twiddle -> row FFT -> final transpose.
 * The final transpose is in-place for large square decompositions; other
 * decompositions retain a D2D copy to return results to out_device.
 * See README.md for dispatch, timing methodology and known API limitations.
 */

#include "fft_cuda.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

// =================================================================================
//                            Basic Complex Arithmetic
// =================================================================================

__device__ __host__ cpxcuda operator+ (const cpxcuda &a, const cpxcuda &b) {
    cpxcuda result;
    result.re = a.re + b.re;
    result.im = a.im + b.im;
    return result;
}

__device__ __host__ cpxcuda operator- (const cpxcuda &a, const cpxcuda &b) {
    cpxcuda result;
    result.re = a.re - b.re;
    result.im = a.im - b.im;
    return result;
}

// =================================================================================
//                                CUDA Utilities
// =================================================================================

#define CUDA_CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, cudaGetErrorString(err)); \
        exit(EXIT_FAILURE); \
    } \
} while(0)

// ============================================================================
// 優化參數定義
// ============================================================================
#define TILE_DIM 32
#define BLOCK_ROWS 8

// Extra column changes the shared-memory row stride in transpose tiles.
// Actual bank conflicts depend on complex-double access instructions; padding
// is not a guarantee of conflict-free access or a measured occupancy increase.
#define TILE_PADDING 1

// Precompute full 1024-point twiddle factor table on host
void init_weights_1024_host(cpxcuda *ws_host, bool reverse) {
    const int N = 1024;
    double sign = reverse ? 1.0 : -1.0;
    for (int k = 0; k < N; k++) {
        double angle = sign * 2.0 * M_PI * k / N;
        ws_host[k].re = cos(angle);
        ws_host[k].im = sin(angle);
    }
}

// =================================================================================
//                        Mixed Bit Reversal
// =================================================================================

__device__ __forceinline__ unsigned int mixed_reversal(unsigned int x, int log_n) {
    unsigned int r2, r4, rev_r4;

    switch (log_n) {
        case 2: return x & 3; // N=4
        case 3: // N=8
            r2 = (x >> 2) & 1; r4 = x & 3;
            return (r4 << 1) | r2;
        case 4: return ((x & 3) << 2) | ((x >> 2) & 3); // N=16
        case 5: // N=32
            r2 = (x >> 4) & 1; r4 = x & 15;
            rev_r4 = ((r4 & 3) << 2) | ((r4 >> 2) & 3);
            return (rev_r4 << 1) | r2;
        case 6: // N=64
            return ((x & 3) << 4) | (((x >> 2) & 3) << 2) | ((x >> 4) & 3);
        case 7: // N=128
            r2 = (x >> 6) & 1; r4 = x & 63;
            rev_r4 = ((r4 & 3) << 4) | (((r4 >> 2) & 3) << 2) | ((r4 >> 4) & 3);
            return (rev_r4 << 1) | r2;
        case 8: // N=256
            return ((x & 3) << 6) | (((x >> 2) & 3) << 4) |
                   (((x >> 4) & 3) << 2) | ((x >> 6) & 3);
        case 9: // N=512
            r2 = (x >> 8) & 1; r4 = x & 255;
            rev_r4 = ((r4 & 3) << 6) | (((r4 >> 2) & 3) << 4) |
                     (((r4 >> 4) & 3) << 2) | ((r4 >> 6) & 3);
            return (rev_r4 << 1) | r2;
        case 10: // N=1024
            return ((x & 3) << 8) | (((x >> 2) & 3) << 6) |
                   (((x >> 4) & 3) << 4) | (((x >> 6) & 3) << 2) | ((x >> 8) & 3);
        default: return x;
    }
}

// =================================================================================
//                         Radix-4 Butterfly (DIT)
// =================================================================================

// Forward radix-4 DIT butterfly. The +/-i combinations are forward-specific;
// conjugating the twiddle table alone does not implement a general inverse.
__device__ __forceinline__ void radix4_butterfly_dit(
    cpxcuda &x0, cpxcuda &x1, cpxcuda &x2, cpxcuda &x3,
    const cpxcuda &w1, const cpxcuda &w2, const cpxcuda &w3)
{
    // Step 1: 複數乘法 - 使用單層 FMA（平衡性能和並行性）
    double t1_re = __fma_rn(x1.re, w1.re, -x1.im * w1.im);
    double t1_im = __fma_rn(x1.re, w1.im, x1.im * w1.re);
    double t2_re = __fma_rn(x2.re, w2.re, -x2.im * w2.im);
    double t2_im = __fma_rn(x2.re, w2.im, x2.im * w2.re);
    double t3_re = __fma_rn(x3.re, w3.re, -x3.im * w3.im);
    double t3_im = __fma_rn(x3.re, w3.im, x3.im * w3.re);

    // Step 2: Radix-4 蝶形運算
    double a_re = x0.re + t2_re;
    double a_im = x0.im + t2_im;
    double b_re = x0.re - t2_re;
    double b_im = x0.im - t2_im;
    double c_re = t1_re + t3_re;
    double c_im = t1_im + t3_im;
    double d_re = t1_re - t3_re;
    double d_im = t1_im - t3_im;

    // Step 3: 最終組合
    x0.re = a_re + c_re;
    x0.im = a_im + c_im;
    x1.re = b_re + d_im;
    x1.im = b_im - d_re;
    x2.re = a_re - c_re;
    x2.im = a_im - c_im;
    x3.re = b_re - d_im;
    x3.im = b_im + d_re;
}

// =================================================================================
//                  Core: Mixed-Radix FFT Kernel (Template for TPB)
// =================================================================================

// Compile-time small FFT, selected for N=64, 128 and 256.
template<int N>
__global__ __launch_bounds__(256, 4)  // Compiler resource hint, not measured occupancy.
void fft_small_optimized(cpxcuda * __restrict__ data, const cpxcuda * __restrict__ ws_1024) {
    // Size shared storage to this compile-time transform length.
    __shared__ cpxcuda s_data[N];

    int tid = threadIdx.x;
    int batch_id = blockIdx.x;

    // 計算 log2(N) - 編譯期常量
    constexpr int log_n = (N == 4) ? 2 : (N == 8) ? 3 : (N == 16) ? 4 :
                          (N == 32) ? 5 : (N == 64) ? 6 : (N == 128) ? 7 : 8;

    // 1. Load Data (coalesced, 使用編譯期優化)
    if (tid < N) {
        unsigned int rev = mixed_reversal(tid, log_n);
        cpxcuda val;
        val.re = __ldg(&data[batch_id * N + tid].re);
        val.im = __ldg(&data[batch_id * N + tid].im);
        s_data[rev] = val;
    }
    __syncthreads();

    // 2. Radix-2 stage (如果 N 不是 4 的冪次)
    int current_stage_size = 1;
    if (log_n & 1) {
        if (tid < (N >> 1)) {
            int idx0 = tid * 2;
            int idx1 = idx0 + 1;
            cpxcuda u = s_data[idx0];
            cpxcuda v = s_data[idx1];
            s_data[idx0] = u + v;
            s_data[idx1] = u - v;
        }
        __syncthreads();
        current_stage_size = 2;
    }

    // 3. Radix-4 stages
    while (current_stage_size < N) {
        int layer_block_size = current_stage_size * 4;
        int scale = 1024 / layer_block_size;
        int num_butterflies = N >> 2;

        if (tid < num_butterflies) {
            int block_id = tid / current_stage_size;
            int j = tid % current_stage_size;
            int base = block_id * layer_block_size + j;

            int tw_idx = j * scale;
            cpxcuda w1, w2, w3;
            w1.re = __ldg(&ws_1024[tw_idx].re);
            w1.im = __ldg(&ws_1024[tw_idx].im);
            w2.re = __ldg(&ws_1024[(tw_idx * 2) & 1023].re);
            w2.im = __ldg(&ws_1024[(tw_idx * 2) & 1023].im);
            w3.re = __ldg(&ws_1024[(tw_idx * 3) & 1023].re);
            w3.im = __ldg(&ws_1024[(tw_idx * 3) & 1023].im);

            cpxcuda x0 = s_data[base];
            cpxcuda x1 = s_data[base + current_stage_size];
            cpxcuda x2 = s_data[base + 2 * current_stage_size];
            cpxcuda x3 = s_data[base + 3 * current_stage_size];

            radix4_butterfly_dit(x0, x1, x2, x3, w1, w2, w3);

            s_data[base] = x0;
            s_data[base + current_stage_size] = x1;
            s_data[base + 2 * current_stage_size] = x2;
            s_data[base + 3 * current_stage_size] = x3;
        }
        __syncthreads();
        current_stage_size *= 4;
    }

    // 4. Store result
    if (tid < N) {
        data[batch_id * N + tid] = s_data[tid];
    }
}

// Generic row FFT retained for other row lengths and the small-size dispatcher.
template<int TPB>
__global__ __launch_bounds__(TPB, 2)  // Compiler resource hint, not measured occupancy.
void fft_block_mixed_radix(cpxcuda * __restrict__ data,
                           const cpxcuda * __restrict__ ws_1024,
                           int Ns,
                           int stride)
{
    // Keep the existing allocation. The extra 32 entries are trailing capacity;
    // indices are not padded, so this does not remap butterfly bank accesses.
    __shared__ cpxcuda s_data[1024 + 32];

    int tid = threadIdx.x;
    int batch_id = blockIdx.x;
    int base_offset = batch_id * Ns * stride;

    int log_n = 31 - __clz(Ns);

    // 1. Load Data with coalesced access and bit reversal
    // Separate double loads; no vector-load instruction is assumed.
    #pragma unroll 8
    for (int i = tid; i < Ns; i += TPB) {
        unsigned int rev = mixed_reversal(i, log_n);
        cpxcuda val;
        val.re = __ldg(&data[base_offset + i * stride].re);
        val.im = __ldg(&data[base_offset + i * stride].im);
        s_data[rev] = val;
    }
    __syncthreads();

    // 2. FFT Iterations
    int current_stage_size = 1;

    // Radix-2 stage (if log_n is odd)
    if (log_n & 1) {
        #pragma unroll 4
        for (int i = tid; i < (Ns >> 1); i += TPB) {
            int idx0 = i * 2;
            int idx1 = idx0 + 1;
            cpxcuda u = s_data[idx0];
            cpxcuda v = s_data[idx1];
            s_data[idx0] = u + v;
            s_data[idx1] = u - v;
        }
        __syncthreads();
        current_stage_size = 2;
    }

    // Radix-4 stages with register blocking
    while (current_stage_size < Ns) {
        int layer_block_size = current_stage_size * 4;
        int scale = 1024 / layer_block_size;
        int num_butterflies = Ns >> 2;

        // Each thread handles indices tid, tid+TPB, ... below num_butterflies.
        // Ns=1024 with TPB=256 assigns one butterfly per thread per stage.
        #pragma unroll 4
        for (int i = tid; i < num_butterflies; i += TPB) {
            int block_id = i / current_stage_size;
            int j = i % current_stage_size;
            int base = block_id * layer_block_size + j;

            // 【優化: Twiddle factor 預計算】
            int tw_idx = j * scale;
            cpxcuda w1, w2, w3;
            w1.re = __ldg(&ws_1024[tw_idx].re);
            w1.im = __ldg(&ws_1024[tw_idx].im);
            int tw2 = (tw_idx * 2) & 1023;
            w2.re = __ldg(&ws_1024[tw2].re);
            w2.im = __ldg(&ws_1024[tw2].im);
            int tw3 = (tw_idx * 3) & 1023;
            w3.re = __ldg(&ws_1024[tw3].re);
            w3.im = __ldg(&ws_1024[tw3].im);

            // 【優化: Register blocking - 從 shared memory 載入到 registers】
            cpxcuda x0 = s_data[base];
            cpxcuda x1 = s_data[base + current_stage_size];
            cpxcuda x2 = s_data[base + 2 * current_stage_size];
            cpxcuda x3 = s_data[base + 3 * current_stage_size];

            // Radix-4 butterfly with FMA
            radix4_butterfly_dit(x0, x1, x2, x3, w1, w2, w3);

            // 寫回 shared memory
            s_data[base] = x0;
            s_data[base + current_stage_size] = x1;
            s_data[base + 2 * current_stage_size] = x2;
            s_data[base + 3 * current_stage_size] = x3;
        }
        __syncthreads();
        current_stage_size *= 4;
    }

    // 3. Write Back with coalesced access
    #pragma unroll 4
    for (int i = tid; i < Ns; i += TPB) {
        data[base_offset + i * stride] = s_data[i];
    }
}

// Fixed stage spacing lets the compiler simplify division, modulo and twiddle
// indexing. One butterfly per thread, with the same arithmetic as the generic
// 1024-point path. Keep the barrier after every stage.
template<int STEP>
__device__ __forceinline__ void fft_row_1024_stage(
    cpxcuda *s_data, const cpxcuda * __restrict__ ws_1024) {
    const int tid = threadIdx.x;
    const int base = (tid / STEP) * (4 * STEP) + tid % STEP;
    const int tw_idx = (tid % STEP) * (1024 / (4 * STEP));
    cpxcuda w1, w2, w3;
    w1.re = __ldg(&ws_1024[tw_idx].re);
    w1.im = __ldg(&ws_1024[tw_idx].im);
    const int tw2 = (tw_idx * 2) & 1023;
    w2.re = __ldg(&ws_1024[tw2].re);
    w2.im = __ldg(&ws_1024[tw2].im);
    const int tw3 = (tw_idx * 3) & 1023;
    w3.re = __ldg(&ws_1024[tw3].re);
    w3.im = __ldg(&ws_1024[tw3].im);

    cpxcuda x0 = s_data[base];
    cpxcuda x1 = s_data[base + STEP];
    cpxcuda x2 = s_data[base + 2 * STEP];
    cpxcuda x3 = s_data[base + 3 * STEP];
    radix4_butterfly_dit(x0, x1, x2, x3, w1, w2, w3);
    s_data[base] = x0;
    s_data[base + STEP] = x1;
    s_data[base + 2 * STEP] = x2;
    s_data[base + 3 * STEP] = x3;
    __syncthreads();
}

// Compile-time specialization exposes the five fixed stage spacings to nvcc.
// Selected only inside the forward four-step path for row length 1024 and
// TPB=256: both row passes at N=2^20 and the second pass at N=2^19.
// Generic kernels remain for all other supported row lengths and standalone
// N=1024. Preserve shared layout, FMA arithmetic and stage order.
// Performance must be measured; this is not a claim of improvement.
__global__ __launch_bounds__(256, 2)
void fft_block_1024_specialized(cpxcuda * __restrict__ data,
                                const cpxcuda * __restrict__ ws_1024) {
    __shared__ cpxcuda s_data[1024 + 32];
    const int tid = threadIdx.x;
    const int base_offset = blockIdx.x * 1024;
    #pragma unroll 4
    for (int i = tid; i < 1024; i += 256) {
        const unsigned int rev = mixed_reversal(i, 10);
        cpxcuda val;
        val.re = __ldg(&data[base_offset + i].re);
        val.im = __ldg(&data[base_offset + i].im);
        s_data[rev] = val;
    }
    __syncthreads();

    fft_row_1024_stage<1>(s_data, ws_1024);
    fft_row_1024_stage<4>(s_data, ws_1024);
    fft_row_1024_stage<16>(s_data, ws_1024);
    fft_row_1024_stage<64>(s_data, ws_1024);
    fft_row_1024_stage<256>(s_data, ws_1024);

    #pragma unroll 4
    for (int i = tid; i < 1024; i += 256)
        data[base_offset + i] = s_data[i];
}

// =================================================================================
//                            Transpose Kernels
// =================================================================================
// Tiled out-of-place transpose. Shared storage allows contiguous global
// reads and writes; it does not eliminate the full-array read/write pass.
__global__ __launch_bounds__(256)
void transpose_opt(cpxcuda * __restrict__ out, const cpxcuda * __restrict__ in, int N) {
    // Padded tile stride; bank behavior still depends on generated instructions.
    __shared__ cpxcuda tile[TILE_DIM][TILE_DIM + TILE_PADDING];
    int x = blockIdx.x * TILE_DIM + threadIdx.x;
    int y = blockIdx.y * TILE_DIM + threadIdx.y;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS)
        if (x < N && (y + i) < N)
            tile[threadIdx.y + i][threadIdx.x] = in[(y + i) * N + x];
    __syncthreads();
    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS)
        if (x < N && (y + i) < N)
            out[(y + i) * N + x] = tile[threadIdx.x][threadIdx.y + i];
}

// Each block owns one diagonal tile or one pair of off-diagonal tiles.
// Both tiles must be loaded before either is overwritten. No other block
// touches this pair, so a block barrier is sufficient for in-place safety.
__global__ __launch_bounds__(256)
void transpose_square_inplace(cpxcuda *data, int N) {
    const int tile_col = blockIdx.x;
    const int tile_row = blockIdx.y;
    if (tile_row > tile_col) return;  // Uniform across the entire block.

    __shared__ cpxcuda a[TILE_DIM][TILE_DIM + TILE_PADDING];
    __shared__ cpxcuda b[TILE_DIM][TILE_DIM + TILE_PADDING];
    const int tx = threadIdx.x;
    const int ty = threadIdx.y;
    const int col = tile_col * TILE_DIM;
    const int row = tile_row * TILE_DIM;

    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS) {
        if (col + tx < N && row + ty + i < N)
            a[ty + i][tx] = data[(row + ty + i) * N + col + tx];
        if (tile_row != tile_col && row + tx < N && col + ty + i < N)
            b[ty + i][tx] = data[(col + ty + i) * N + row + tx];
    }
    __syncthreads();

    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS) {
        if (row + tx < N && col + ty + i < N)
            data[(col + ty + i) * N + row + tx] = a[tx][ty + i];
        if (tile_row != tile_col && col + tx < N && row + ty + i < N)
            data[(row + ty + i) * N + col + tx] = b[tx][ty + i];
    }
}

// Rectangular transpose variant (for non-square matrices)
// 使用相同的優化技術，但支援 R != C 的矩陣
__global__ __launch_bounds__(256)
void transpose_rect_opt(cpxcuda * __restrict__ out, const cpxcuda * __restrict__ in, int R, int C) {
    // Use the same padded tile layout as the other transpose kernels.
    __shared__ cpxcuda tile[TILE_DIM][TILE_DIM + TILE_PADDING];
    int x = blockIdx.x * TILE_DIM + threadIdx.x;
    int y = blockIdx.y * TILE_DIM + threadIdx.y;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS)
        if (x < C && (y + i) < R)
            tile[threadIdx.y + i][threadIdx.x] = in[(y + i) * C + x];
    __syncthreads();
    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS)
        if (x < R && (y + i) < C)
            out[(y + i) * R + x] = tile[threadIdx.x][threadIdx.y + i];
}

// Transpose and multiply by the cross-row twiddle in one kernel.
// The DP sincos evaluation remains per element; there is no full-N table.
__global__ __launch_bounds__(256)
void transpose_and_twiddle(cpxcuda * __restrict__ out, const cpxcuda * __restrict__ in,
                           int R, int C, int N, double sign) {
    // Use the same padded tile layout as the other transpose kernels.
    __shared__ cpxcuda tile[TILE_DIM][TILE_DIM + TILE_PADDING];
    int x = blockIdx.x * TILE_DIM + threadIdx.x;
    int y = blockIdx.y * TILE_DIM + threadIdx.y;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS)
        if (x < C && (y + i) < R)
            tile[threadIdx.y + i][threadIdx.x] = in[(y + i) * C + x];
    __syncthreads();
    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;
    double inv_N = 1.0 / (double)N;
    #pragma unroll
    for (int i = 0; i < TILE_DIM; i += BLOCK_ROWS) {
        if (x < R && (y + i) < C) {
            int out_row = y + i;
            int out_col = x;
            long long rc = (long long)out_col * (long long)out_row;
            double angle = sign * 2.0 * M_PI * (double)(rc % N) * inv_N;
            // 使用 CUDA sincos 函數
            double c, s;
            sincos(angle, &s, &c);
            cpxcuda w; w.re = c; w.im = s;
            cpxcuda val = tile[threadIdx.x][threadIdx.y + i];

            // 【優化 3: 單層 FMA 複數乘法 - 保持並行性】
            // result = val * w，使用平衡的 FMA（避免過度依賴）
            cpxcuda result;
            result.re = __fma_rn(val.re, w.re, -val.im * w.im);
            result.im = __fma_rn(val.re, w.im, val.im * w.re);
            out[out_row * R + out_col] = result;
        }
    }
}

// Normalization Kernel
__global__ __launch_bounds__(256)
void normalize_opt(cpxcuda * __restrict__ data, int n, double scale) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx].re *= scale;
        data[idx].im *= scale;
    }
}

// =================================================================================
//                           1D Four-Step FFT (Template for Tuning)
// =================================================================================

// Large forward pipeline (N=R*C, row-major buffers):
// 1. Transpose data(R,C) -> temp(C,R).
// 2. C row FFTs of length R in temp.
// 3. Transpose + cross-row twiddle temp(C,R) -> data(R,C).
// 4. R row FFTs of length C in data.
// 5. Final transpose restores natural 1D frequency order.
// For N>=2^17 and R==C, step 5 is in-place in data. Otherwise it writes
// temp and the caller copies temp back to data. All three transposes are
// required in this implementation; the output permutation is not optional.
// Optional stage_events[0..5] are caller-owned timing-enabled CUDA events.
// They cover the five stages, not the caller's fallback D2D copy. The existing
// diagnostic caller uses N=2^20, forward, batch=1, which needs no final copy.
// Plan creation rejects inverse requests; the legacy reverse branch is not used.
// Returns true when the caller must copy temp_device back to data_device.
template <int TPB>
bool fft_1d_fourstep_opt(cpxcuda *data_device, cpxcuda *temp_device, cpxcuda *ws_device,
                         int N, int R, int C, bool reverse, cudaStream_t stream,
                         const cudaEvent_t *stage_events = nullptr) {
    // block_fft 改用 TPB
    dim3 block_fft(TPB);
    dim3 block_t(TILE_DIM, BLOCK_ROWS);
    dim3 grid_t_RC((C + TILE_DIM - 1) / TILE_DIM, (R + TILE_DIM - 1) / TILE_DIM);
    dim3 grid_t_CR((R + TILE_DIM - 1) / TILE_DIM, (C + TILE_DIM - 1) / TILE_DIM);
    double sign = reverse ? 1.0 : -1.0;

    if (!reverse) {
        // Step 1: 第一次轉置 (data -> temp)
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[0], stream));
        if (R == C) transpose_opt<<<grid_t_RC, block_t, 0, stream>>>(temp_device, data_device, R);
        else transpose_rect_opt<<<grid_t_RC, block_t, 0, stream>>>(temp_device, data_device, R, C);
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[1], stream));

        // Step 2: 對每一行執行 FFT (in-place on temp)
        if (TPB == 256 && R == 1024)
            fft_block_1024_specialized<<<C, block_fft, 0, stream>>>(temp_device, ws_device);
        else
            fft_block_mixed_radix<TPB><<<C, block_fft, 0, stream>>>(temp_device, ws_device, R, 1);
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[2], stream));

        // Step 3: 轉置 + Twiddle Factor 乘法 (temp -> data)
        transpose_and_twiddle<<<grid_t_CR, block_t, 0, stream>>>(data_device, temp_device, C, R, N, sign);
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[3], stream));

        // Step 4: R contiguous row FFTs of length C (in-place on data).
        if (TPB == 256 && C == 1024)
            fft_block_1024_specialized<<<R, block_fft, 0, stream>>>(data_device, ws_device);
        else
            fft_block_mixed_radix<TPB><<<R, block_fft, 0, stream>>>(data_device, ws_device, C, 1);
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[4], stream));

        // Large square forward transforms finish in data, preserving natural
        // output order without a separate D2D copy. Other sizes keep the baseline.
        if (N >= (1 << 17) && R == C) {
            transpose_square_inplace<<<grid_t_RC, block_t, 0, stream>>>(data_device, R);
            if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[5], stream));
            return false;
        }

        // Step 5: 最後轉置 (data -> temp)
        // 【保留這一步以確保正確性】
        if (R == C) transpose_opt<<<grid_t_RC, block_t, 0, stream>>>(temp_device, data_device, R);
        else transpose_rect_opt<<<grid_t_RC, block_t, 0, stream>>>(temp_device, data_device, R, C);
        if (stage_events) CUDA_CHECK(cudaEventRecord(stage_events[5], stream));
    } else {
        // Unimplemented legacy branch; public plan creation rejects reverse=true.
    }
    return true;
}

// =================================================================================
//                           1D FFT Plan Management
// =================================================================================

fft_plan_cuda fft_plan_cuda_1d(int n, int batch, cpxcuda *in, cpxcuda *out, bool reverse) {
    // Validate before accessing caller buffers or allocating CUDA resources.
    if (reverse) {
        fprintf(stderr, "fft_plan_cuda_1d: inverse FFT (reverse=true) is unsupported.\n");
        exit(EXIT_FAILURE);
    }
    if (n <= 0 || (n & (n - 1)) != 0) {
        fprintf(stderr, "fft_plan_cuda_1d: N must be a positive power of two (got %d).\n", n);
        exit(EXIT_FAILURE);
    }
    int upper_n = 1, log_n = 0;
    while (upper_n < n) { upper_n <<= 1; log_n++; }

    int R, C;
    if (log_n <= 10) {
        R = 1; C = upper_n;
    } else if (log_n % 2 == 0) {
        R = C = 1 << (log_n / 2);
    } else {
        R = 1 << (log_n / 2);
        C = 1 << ((log_n + 1) / 2);
    }

    // Validation above ensures upper_n == n; retain existing host copy/upload.
    for (int i = 0; i < batch; i++)
        for (int j = 0; j < upper_n; j++)
            out[i * upper_n + j] = in[i * upper_n + j];

    cpxcuda *out_device = NULL;
    CUDA_CHECK(cudaMalloc(&out_device, sizeof(cpxcuda) * batch * upper_n));
    CUDA_CHECK(cudaMemcpy(out_device, out, sizeof(cpxcuda) * upper_n * batch, cudaMemcpyHostToDevice));

    cpxcuda *temp_device = NULL;
    CUDA_CHECK(cudaMalloc(&temp_device, sizeof(cpxcuda) * upper_n));

    cpxcuda *ws_device = NULL;
    CUDA_CHECK(cudaMalloc(&ws_device, sizeof(cpxcuda) * 1024));
    cpxcuda *ws_host = (cpxcuda *)malloc(sizeof(cpxcuda) * 1024);
    init_weights_1024_host(ws_host, reverse);
    CUDA_CHECK(cudaMemcpy(ws_device, ws_host, sizeof(cpxcuda) * 1024, cudaMemcpyHostToDevice));
    free(ws_host);

    fft_plan_cuda plan;
    plan.n = upper_n;
    plan.batch = batch;
    plan.R = R;
    plan.C = C;
    plan.out = out;
    plan.out_device = out_device;
    plan.ws_device = ws_device;
    plan.temp_device = temp_device;
    plan.reverse = reverse;
    return plan;
}

void fft_execute_plan_cuda_async(fft_plan_cuda &plan, cudaStream_t stream) {
    for (int b = 0; b < plan.batch; b++) {
        cpxcuda *batch_data = plan.out_device + b * plan.n;
        cpxcuda *batch_temp = plan.temp_device;

        if (plan.R == 1) {
            // 【小規模: 單 kernel FFT】
            switch(plan.n) {
                case 64:  fft_small_optimized<64> <<<1, 64, 0, stream>>>(batch_data, plan.ws_device); break;
                case 128: fft_small_optimized<128><<<1, 128, 0, stream>>>(batch_data, plan.ws_device); break;
                case 256: fft_small_optimized<256><<<1, 256, 0, stream>>>(batch_data, plan.ws_device); break;
                case 512: fft_block_mixed_radix<256><<<1, 256, 0, stream>>>(batch_data, plan.ws_device, 512, 1); break;
                case 1024: fft_block_mixed_radix<256><<<1, 256, 0, stream>>>(batch_data, plan.ws_device, 1024, 1); break;
                default:  fft_block_mixed_radix<256><<<1, 256, 0, stream>>>(batch_data, plan.ws_device, plan.n, 1); break;
            }
            if(plan.reverse) normalize_opt<<<(plan.n+255)/256, 256, 0, stream>>>(batch_data, plan.n, 1.0/plan.n);
        } else {
            // Existing dispatch: TPB=128 through 2^14, otherwise TPB=256.
            // The forward helper selects the fixed 1024-point row kernel
            // where applicable; other row lengths keep the generic kernel.
            int log_n = 31 - __builtin_clz(plan.n);
            bool needs_copy;
            if (log_n <= 14) {
                // 中規模: 使用 128 threads per block
                needs_copy = fft_1d_fourstep_opt<128>(batch_data, batch_temp, plan.ws_device, plan.n, plan.R, plan.C, plan.reverse, stream);
            } else {
                // 大規模: 使用 256 threads per block
                needs_copy = fft_1d_fourstep_opt<256>(batch_data, batch_temp, plan.ws_device, plan.n, plan.R, plan.C, plan.reverse, stream);
            }
            if (needs_copy) {
                CUDA_CHECK(cudaMemcpyAsync(batch_data, batch_temp, plan.n * sizeof(cpxcuda),
                                           cudaMemcpyDeviceToDevice, stream));
            }
        }
    }

    CUDA_CHECK(cudaGetLastError());
}

void fft_execute_plan_cuda(fft_plan_cuda &plan) {
    cudaStream_t stream;
    CUDA_CHECK(cudaStreamCreate(&stream));
    fft_execute_plan_cuda_async(plan, stream);
    CUDA_CHECK(cudaStreamSynchronize(stream));
    CUDA_CHECK(cudaStreamDestroy(stream));
}

void fft_destroy_plan_cuda(fft_plan_cuda &plan) {
    cudaFree(plan.ws_device);
    cudaFree(plan.out_device);
    cudaFree(plan.temp_device);
}
