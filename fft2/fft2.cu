#include "fft2.h"
#include "detail/tile_policy.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <type_traits>
#include <vector>

namespace fft2 {
namespace {

constexpr unsigned int kThreads = 256;
constexpr size_t kDefaultSharedLimit = 48 * 1024;
static_assert(sizeof(cuDoubleComplex) == 2 * sizeof(double));
using detail::choose_tile;
using detail::shared_bytes;

void check_cuda(cudaError_t status, const char* operation) {
    if (status != cudaSuccess) {
        throw std::runtime_error(std::string("fft2: ") + operation + ": " + cudaGetErrorString(status));
    }
}

bool power_of_two(size_t value) {
    return value != 0 && (value & (value - 1)) == 0;
}

int integer_log2(size_t value) {
    int exponent = 0;
    while (value > 1) {
        value >>= 1;
        ++exponent;
    }
    return exponent;
}

// A buffer always releases on its allocation device, even if the caller changed
// devices. Destructors cannot report CUDA errors; execute/setup calls do.
struct DeviceArray {
    cuDoubleComplex* data = nullptr;
    int device = -1;

    DeviceArray() = default;
    DeviceArray(const DeviceArray&) = delete;
    DeviceArray& operator=(const DeviceArray&) = delete;

    ~DeviceArray() {
        if (data == nullptr) {
            return;
        }
        int current = -1;
        const bool restore = cudaGetDevice(&current) == cudaSuccess && current != device;
        if (restore && cudaSetDevice(device) != cudaSuccess) {
            return;
        }
        (void)cudaFree(data);
        if (restore) {
            (void)cudaSetDevice(current);
        }
    }

    void allocate(size_t bytes) {
        check_cuda(cudaGetDevice(&device), "get allocation device");
        check_cuda(cudaMalloc(reinterpret_cast<void**>(&data), bytes), "allocate device buffer");
    }

    void upload(const std::vector<cuDoubleComplex>& values) {
        const size_t bytes = values.size() * sizeof(cuDoubleComplex);
        allocate(bytes);
        check_cuda(cudaMemcpy(data, values.data(), bytes, cudaMemcpyHostToDevice), "upload twiddle table");
    }
};

std::vector<cuDoubleComplex> make_table(size_t period, size_t count, size_t step) {
    const long double two_pi = 2.0L * std::acos(-1.0L);
    std::vector<cuDoubleComplex> result(count);
    for (size_t index = 0; index < count; ++index) {
        // These products are <= N, but reduction is explicit, before conversion
        // to floating point. No trigonometry is evaluated at execution time.
        const uint64_t exponent = (static_cast<uint64_t>(index) * static_cast<uint64_t>(step))
                                  % static_cast<uint64_t>(period);
        const long double angle = -two_pi * static_cast<long double>(exponent)
                                  / static_cast<long double>(period);
        result[index] = make_cuDoubleComplex(static_cast<double>(std::cos(angle)),
                                            static_cast<double>(std::sin(angle)));
    }
    return result;
}

// Both axes and the arbitrary-width fallback are compile-time choices. Mode 0
// retains v1's size_t expressions and floating-point operation order. In mode 1
// every offset within one transform fits uint32_t (N <= 2^24); only the batch
// base/global address needs size_t. Explicit non-power-of-two tile widths keep
// working through a separately instantiated u32 division/remainder path.
template <int Mode, int Padding, bool PowerTwoLanes = true>
struct KernelVariant {
    using Index = std::conditional_t<Mode == 0, size_t, uint32_t>;

    __device__ static __forceinline__ Index quotient(Index value, Index divisor, int log_divisor) {
        if constexpr (Mode == 1) { return value >> log_divisor; }
        else { return value / divisor; }
    }

    __device__ static __forceinline__ Index remainder(Index value, Index divisor) {
        if constexpr (Mode == 1) { return value & (divisor - 1); }
        else { return value % divisor; }
    }

    __device__ static __forceinline__ Index lane_quotient(Index value, Index lanes, int log_lanes) {
        if constexpr (Mode == 1 && !PowerTwoLanes) { return value / lanes; }
        else { return quotient(value, lanes, log_lanes); }
    }

    __device__ static __forceinline__ Index lane_remainder(Index value, Index lanes) {
        if constexpr (Mode == 1 && !PowerTwoLanes) { return value % lanes; }
        else { return remainder(value, lanes); }
    }

    __device__ static __forceinline__ Index shared_index(Index element, Index lane, int lanes) {
        return element * (static_cast<Index>(lanes) + static_cast<Index>(Padding)) + lane;
    }
};

template <int Mode, int Padding, typename Action>
void dispatch_width(int lanes, const Action& action) {
    if constexpr (Mode == 0) {
        action(KernelVariant<Mode, Padding>{});
    } else if (power_of_two(static_cast<size_t>(lanes))) {
        action(KernelVariant<Mode, Padding>{});
    } else {
        action(KernelVariant<Mode, Padding, false>{});
    }
}

template <int Mode, typename Action>
void dispatch_padding(int padding, int lanes, const Action& action) {
    switch (padding) {
        case 0: dispatch_width<Mode, 0>(lanes, action); break;
        case 1: dispatch_width<Mode, 1>(lanes, action); break;
        case 2: dispatch_width<Mode, 2>(lanes, action); break;
        default: throw std::runtime_error("fft2: smem_padding must be 0, 1 or 2");
    }
}

template <typename Action>
void dispatch_variant(int mode, int padding, int lanes, const Action& action) {
    if (mode == 0) { dispatch_padding<0>(padding, lanes, action); }
    else { dispatch_padding<1>(padding, lanes, action); }
}

__device__ __forceinline__ cuDoubleComplex add(cuDoubleComplex a, cuDoubleComplex b) {
    return make_cuDoubleComplex(a.x + b.x, a.y + b.y);
}

__device__ __forceinline__ cuDoubleComplex sub(cuDoubleComplex a, cuDoubleComplex b) {
    return make_cuDoubleComplex(a.x - b.x, a.y - b.y);
}

__device__ __forceinline__ cuDoubleComplex mul(cuDoubleComplex a, cuDoubleComplex b) {
    return make_cuDoubleComplex(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

template <typename Index>
__device__ __forceinline__ cuDoubleComplex read_twiddle(const cuDoubleComplex* table, Index index) {
    return make_cuDoubleComplex(__ldg(&table[index].x), __ldg(&table[index].y));
}

template <typename Index>
__device__ __forceinline__ Index reverse_index(Index index, int log_length) {
    return static_cast<Index>(__brev(static_cast<unsigned int>(index)) >> (32 - log_length));
}

// On entry shared[element, lane] already contains bit-reversed input.
// Each thread holds four values and fuses two radix-2 DIT stages into one
// radix-4 stage. Butterfly sets are disjoint; a block barrier follows each stage.
// Formulas are independently exercised by reference.block_fft().
template <typename V>
__device__ void block_fft(cuDoubleComplex* shared, int length, int lanes, int log_length, int log_lanes,
                          const cuDoubleComplex* roots) {
    using Index = typename V::Index;
    const Index width = static_cast<Index>(lanes);
    const Index fft_length = static_cast<Index>(length);
    int log_span = 2;
    for (Index span = 4; span <= fft_length; span *= 4, log_span += 2) {
        const Index quarter = span / 4;
        const Index count = (fft_length / 4) * width;
        for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
            const Index butterfly = V::lane_quotient(flat, width, log_lanes);
            const Index lane = V::lane_remainder(flat, width);
            const Index j = V::remainder(butterfly, quarter);
            const Index start = V::quotient(butterfly, quarter, log_span - 2) * span + j;
            const Index exponent = j * V::quotient(fft_length, span, log_span);
            const cuDoubleComplex w1 = read_twiddle(roots, exponent);
            const cuDoubleComplex w2 = read_twiddle(roots, 2 * exponent);
            const cuDoubleComplex a0 = shared[V::shared_index(start, lane, lanes)];
            const cuDoubleComplex a1 = mul(shared[V::shared_index(start + quarter, lane, lanes)], w2);
            const cuDoubleComplex a2 = shared[V::shared_index(start + 2 * quarter, lane, lanes)];
            const cuDoubleComplex a3 = mul(shared[V::shared_index(start + 3 * quarter, lane, lanes)], w2);
            const cuDoubleComplex u0 = add(a0, a1);
            const cuDoubleComplex u1 = sub(a0, a1);
            const cuDoubleComplex u2 = mul(add(a2, a3), w1);
            const cuDoubleComplex rotated = mul(sub(a2, a3), w1);
            const cuDoubleComplex u3 = make_cuDoubleComplex(rotated.y, -rotated.x);  // -i * rotated
            shared[V::shared_index(start, lane, lanes)] = add(u0, u2);
            shared[V::shared_index(start + quarter, lane, lanes)] = add(u1, u3);
            shared[V::shared_index(start + 2 * quarter, lane, lanes)] = sub(u0, u2);
            shared[V::shared_index(start + 3 * quarter, lane, lanes)] = sub(u1, u3);
        }
        __syncthreads();
    }
    if ((log_length & 1) != 0) {
        const Index half = fft_length / 2;
        for (Index flat = threadIdx.x; flat < half * width; flat += blockDim.x) {
            const Index j = V::lane_quotient(flat, width, log_lanes);
            const Index lane = V::lane_remainder(flat, width);
            const cuDoubleComplex a = shared[V::shared_index(j, lane, lanes)];
            const cuDoubleComplex b = mul(shared[V::shared_index(j + half, lane, lanes)],
                                          read_twiddle(roots, j));
            shared[V::shared_index(j, lane, lanes)] = add(a, b);
            shared[V::shared_index(j + half, lane, lanes)] = sub(a, b);
        }
        __syncthreads();
    }
}

struct LegacyFFT {
    template <typename V>
    __device__ static __forceinline__ void run(cuDoubleComplex* shared, int length, int lanes,
                                               int log_length, int log_lanes,
                                               const cuDoubleComplex* roots) {
        block_fft<V>(shared, length, lanes, log_length, log_lanes, roots);
    }
};

// Internal W_16 roots for exponents 0..7. Unrolled register butterflies only
// reference constant indices; radix-8/4/2 use subsets of these same constants.
template <int R, int Half = 1>
__device__ __forceinline__ void register_butterfly(cuDoubleComplex (&v)[R]) {
    constexpr double c = 0.923879532511286756128183189396788286;
    constexpr double s = 0.382683432365089771728459984030398867;
    constexpr double h = 0.707106781186547524400844362104849039;
    constexpr double real[] = {1.0, c, h, s, 0.0, -s, -h, -c};
    constexpr double imag[] = {0.0, -s, -h, -c, -1.0, -c, -h, -s};
    #pragma unroll
    for (int base = 0; base < R; base += 2 * Half) {
        #pragma unroll
        for (int j = 0; j < Half; ++j) {
            const int exponent = j * (8 / Half);
            const cuDoubleComplex a = v[base + j];
            const cuDoubleComplex b = mul(v[base + j + Half],
                                          make_cuDoubleComplex(real[exponent], imag[exponent]));
            v[base + j] = add(a, b);
            v[base + j + Half] = sub(a, b);
        }
    }
    if constexpr (2 * Half < R) { register_butterfly<R, 2 * Half>(v); }
}

template <int LogLength, int RadixBits>
struct RegisterFFT {
    // The host selects LogLength/RadixBits. The recursion forms the complete
    // stage plan at compile time, including the smaller final radix.
    template <typename V, int Done = 0>
    __device__ static __forceinline__ void stage(cuDoubleComplex* shared, int lanes,
                                                 int log_lanes, const cuDoubleComplex* roots) {
        using Index = typename V::Index;
        constexpr int bits = LogLength - Done < RadixBits ? LogLength - Done : RadixBits;
        constexpr int radix = 1 << bits;
        constexpr int previous = 1 << Done;
        constexpr int span = previous * radix;
        constexpr int length = 1 << LogLength;
        const Index width = static_cast<Index>(lanes);
        const Index count = (length / radix) * width;
        for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
            const Index butterfly = V::lane_quotient(flat, width, log_lanes);
            const Index lane = V::lane_remainder(flat, width);
            const Index j = V::remainder(butterfly, static_cast<Index>(previous));
            const Index start = V::quotient(butterfly, static_cast<Index>(previous), Done) * span + j;
            cuDoubleComplex v[radix];
            #pragma unroll
            for (int t = 0; t < radix; ++t) {
                // Shared input is bit reversed within each radix. External
                // twiddles use the natural (reversed t) sub-FFT number.
                const Index exponent = reverse_index(static_cast<Index>(t), bits) * j * (length / span);
                v[t] = mul(shared[V::shared_index(start + t * previous, lane, lanes)],
                            read_twiddle(roots, exponent));
            }
            // No shared access or barrier between these internal DIT stages.
            register_butterfly(v);
            #pragma unroll
            for (int t = 0; t < radix; ++t) {
                shared[V::shared_index(start + t * previous, lane, lanes)] = v[t];
            }
        }
        // Every butterfly reads/writes its own disjoint set. One barrier is
        // enough, including threads processing several flat values. The same
        // single exchange allocation also serves global load/store layout.
        __syncthreads();
        if constexpr (Done + bits < LogLength) { stage<V, Done + bits>(shared, lanes, log_lanes, roots); }
    }

    template <typename V>
    __device__ static __forceinline__ void run(cuDoubleComplex* shared, int, int lanes,
                                               int, int log_lanes, const cuDoubleComplex* roots) {
        stage<V>(shared, lanes, log_lanes, roots);
    }
};

template <int Bits, typename Action>
void dispatch_register_fft(int log_length, const Action& action) {
    switch (log_length) {
        case 8: action(RegisterFFT<8, Bits>{}); break;
        case 9: action(RegisterFFT<9, Bits>{}); break;
        case 10: action(RegisterFFT<10, Bits>{}); break;
        case 11: action(RegisterFFT<11, Bits>{}); break;
        case 12: action(RegisterFFT<12, Bits>{}); break;
        default: throw std::runtime_error("fft2: register FFT length must be 256..4096");
    }
}

template <typename Action>
void dispatch_kernel(int mode, int padding, int lanes, int radix_mode, int log_length, const Action& action) {
    dispatch_variant(mode, padding, lanes, [&](auto variant) {
        if (radix_mode == 0) { action(variant, LegacyFFT{}); }
        else if (radix_mode == 1) {
            dispatch_register_fft<3>(log_length, [&](auto fft) { action(variant, fft); });
        } else {
            dispatch_register_fft<4>(log_length, [&](auto fft) { action(variant, fft); });
        }
    });
}

template <typename V, typename FFT>
__global__ void pass1_columns(const cuDoubleComplex* __restrict__ input,
                               cuDoubleComplex* __restrict__ workspace, size_t n, int batch,
                               int n1, int n2, int cols, int log_n1, int log_cols,
                               size_t cross_base, int log_cross_base,
                               const cuDoubleComplex* __restrict__ roots,
                               const cuDoubleComplex* __restrict__ cross_low,
                               const cuDoubleComplex* __restrict__ cross_high) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;  // Uniform for the whole block, before any barrier.
    }
    extern __shared__ cuDoubleComplex shared[];
    using Index = typename V::Index;
    const size_t base = batch_index * n;
    const Index first_col = static_cast<Index>(blockIdx.x) * static_cast<Index>(cols);
    const Index width = static_cast<Index>(cols);
    const Index count = static_cast<Index>(n1) * width;
    // Reference pass 1: flat = n1_index * C + lane.
    for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const Index element = V::lane_quotient(flat, width, log_cols);
        const Index lane = V::lane_remainder(flat, width);
        const Index column = first_col + lane;
        const cuDoubleComplex value = column < static_cast<Index>(n2)
            ? input[base + element * static_cast<Index>(n2) + column]
            : make_cuDoubleComplex(0.0, 0.0);
        shared[V::shared_index(reverse_index(element, log_n1), lane, cols)] = value;
    }
    __syncthreads();
    FFT::template run<V>(shared, n1, cols, log_n1, log_cols, roots);
    for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const Index k1 = V::lane_quotient(flat, width, log_cols);
        const Index lane = V::lane_remainder(flat, width);
        const Index column = first_col + lane;
        if (column < static_cast<Index>(n2)) {
            // column < N2 and k1 < N1 imply column*k1 < N <= 2^24.
            const Index exponent = V::remainder(column * k1, static_cast<Index>(n));
            const cuDoubleComplex cross = mul(
                read_twiddle(cross_high, V::quotient(exponent, static_cast<Index>(cross_base), log_cross_base)),
                read_twiddle(cross_low, V::remainder(exponent, static_cast<Index>(cross_base))));
            workspace[base + k1 * static_cast<Index>(n2) + column] =
                mul(shared[V::shared_index(k1, lane, cols)], cross);
        }
    }
}

template <typename V, typename FFT>
__global__ void pass2_rows(const cuDoubleComplex* __restrict__ workspace,
                           cuDoubleComplex* __restrict__ output, size_t n, int batch,
                           int n1, int n2, int rows, int log_n2, int log_rows,
                           const cuDoubleComplex* __restrict__ roots) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;
    }
    extern __shared__ cuDoubleComplex shared[];
    using Index = typename V::Index;
    const size_t base = batch_index * n;
    const Index first_row = static_cast<Index>(blockIdx.x) * static_cast<Index>(rows);
    const Index width = static_cast<Index>(rows);
    const Index count = static_cast<Index>(n2) * width;
    // Reference pass 2 LOAD: flat = lane * N2 + n2_index (contiguous rows).
    for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const Index lane = V::quotient(flat, static_cast<Index>(n2), log_n2);
        const Index element = V::remainder(flat, static_cast<Index>(n2));
        const Index row = first_row + lane;
        const cuDoubleComplex value = row < static_cast<Index>(n1)
            ? workspace[base + row * static_cast<Index>(n2) + element]
            : make_cuDoubleComplex(0.0, 0.0);
        shared[V::shared_index(reverse_index(element, log_n2), lane, rows)] = value;
    }
    __syncthreads();
    FFT::template run<V>(shared, n2, rows, log_n2, log_rows, roots);
    // Reference pass 2 STORE: flat = k2 * R + lane (adjacent output k1's).
    for (Index flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const Index k2 = V::lane_quotient(flat, width, log_rows);
        const Index lane = V::lane_remainder(flat, width);
        const Index row = first_row + lane;
        if (row < static_cast<Index>(n1)) {
            output[base + row + static_cast<Index>(n1) * k2] = shared[V::shared_index(k2, lane, rows)];
        }
    }
}

}  // namespace

struct Plan::Impl {
    size_t n;
    int batch;
    int n1;
    int n2;
    int log_n1;
    int log_n2;
    int cols;
    int rows;
    int log_cols;
    int log_rows;
    int log_cross_base;
    int index_mode;
    int smem_padding;
    int tile_policy;
    int radix_mode;
    int device = -1;
    size_t bytes;
    size_t shared1;
    size_t shared2;
    size_t cross_base;
    dim3 grid1;
    dim3 grid2;
    DeviceArray workspace;
    DeviceArray roots1;
    DeviceArray roots2;
    DeviceArray cross_low;
    DeviceArray cross_high;

    Impl(size_t requested_n, int requested_batch, PlanOptions opts) : n(requested_n), batch(requested_batch) {
        if (!power_of_two(n) || n < (size_t{1} << 16) || n > (size_t{1} << 24)) {
            throw std::runtime_error("fft2: N must be a power of two in [2^16, 2^24]");
        }
        if (batch < 1) {
            throw std::runtime_error("fft2: batch must be >= 1");
        }
        if (opts.index_mode < 0 || opts.index_mode > 1) {
            throw std::runtime_error("fft2: index_mode must be 0 or 1");
        }
        if (opts.smem_padding < 0 || opts.smem_padding > 2) {
            throw std::runtime_error("fft2: smem_padding must be 0, 1 or 2");
        }
        if (opts.tile_policy < 0 || opts.tile_policy > 1) {
            throw std::runtime_error("fft2: tile_policy must be 0 or 1");
        }
        if (opts.radix_mode < 0 || opts.radix_mode > 2) {
            throw std::runtime_error("fft2: radix_mode must be 0, 1 or 2");
        }
        index_mode = opts.index_mode;
        smem_padding = opts.smem_padding;
        tile_policy = opts.tile_policy;
        radix_mode = opts.radix_mode;
        if (n > std::numeric_limits<size_t>::max() / static_cast<size_t>(batch)
            || n * static_cast<size_t>(batch) > std::numeric_limits<size_t>::max() / sizeof(cuDoubleComplex)) {
            throw std::runtime_error("fft2: N * batch byte count overflows size_t");
        }
        const int log_n = integer_log2(n);
        n1 = opts.n1 == 0 ? (1 << (log_n / 2)) : opts.n1;
        if (n1 < 256 || n1 > 4096 || !power_of_two(static_cast<size_t>(n1))
            || n % static_cast<size_t>(n1) != 0) {
            throw std::runtime_error("fft2: N1 must be a power-of-two factor of N in [256, 4096]");
        }
        n2 = static_cast<int>(n / static_cast<size_t>(n1));
        if (n2 < 256 || n2 > 4096) {
            throw std::runtime_error("fft2: N2 = N / N1 must be in [256, 4096]");
        }
        log_n1 = integer_log2(static_cast<size_t>(n1));
        log_n2 = integer_log2(static_cast<size_t>(n2));
        log_cross_base = (log_n + 1) / 2;
        cross_base = size_t{1} << log_cross_base;
        bytes = n * static_cast<size_t>(batch) * sizeof(cuDoubleComplex);

        check_cuda(cudaGetDevice(&device), "get plan device");
        int optin_limit = 0;
        check_cuda(cudaDeviceGetAttribute(&optin_limit, cudaDevAttrMaxSharedMemoryPerBlockOptin, device),
                   "query opt-in shared-memory limit");
        if (optin_limit <= 0) {
            throw std::runtime_error("fft2: device reports no opt-in shared memory");
        }
        const size_t limit = static_cast<size_t>(optin_limit);
        cols = choose_tile(n1, n2, opts.tile_cols, smem_padding, limit, "tile_cols", tile_policy);
        rows = choose_tile(n2, n1, opts.tile_rows, smem_padding, limit, "tile_rows", tile_policy);
        log_cols = integer_log2(static_cast<size_t>(cols));
        log_rows = integer_log2(static_cast<size_t>(rows));
        shared1 = shared_bytes(n1, cols, smem_padding);
        shared2 = shared_bytes(n2, rows, smem_padding);

        int max_x = 0;
        int max_y = 0;
        int max_z = 0;
        check_cuda(cudaDeviceGetAttribute(&max_x, cudaDevAttrMaxGridDimX, device), "query grid.x limit");
        check_cuda(cudaDeviceGetAttribute(&max_y, cudaDevAttrMaxGridDimY, device), "query grid.y limit");
        check_cuda(cudaDeviceGetAttribute(&max_z, cudaDevAttrMaxGridDimZ, device), "query grid.z limit");
        const size_t grid_y = std::min(static_cast<size_t>(batch), static_cast<size_t>(max_y));
        const size_t grid_z = (static_cast<size_t>(batch) + grid_y - 1) / grid_y;
        const size_t grid_x1 = (static_cast<size_t>(n2) + static_cast<size_t>(cols) - 1) / static_cast<size_t>(cols);
        const size_t grid_x2 = (static_cast<size_t>(n1) + static_cast<size_t>(rows) - 1) / static_cast<size_t>(rows);
        if (grid_z > static_cast<size_t>(max_z) || grid_x1 > static_cast<size_t>(max_x)
            || grid_x2 > static_cast<size_t>(max_x)) {
            throw std::runtime_error("fft2: requested split/batch exceeds device grid dimensions");
        }
        grid1 = dim3(static_cast<unsigned int>(grid_x1), static_cast<unsigned int>(grid_y),
                     static_cast<unsigned int>(grid_z));
        grid2 = dim3(static_cast<unsigned int>(grid_x2), static_cast<unsigned int>(grid_y),
                     static_cast<unsigned int>(grid_z));

        if (limit > kDefaultSharedLimit) {
            // Set the full device limit, never a smaller plan's requirement:
            // constructing another plan must not invalidate an existing plan.
            dispatch_kernel(index_mode, smem_padding, cols, radix_mode, log_n1, [&](auto variant, auto fft) {
                check_cuda(cudaFuncSetAttribute(pass1_columns<decltype(variant), decltype(fft)>,
                                               cudaFuncAttributeMaxDynamicSharedMemorySize, optin_limit),
                           "opt in pass 1 dynamic shared memory");
            });
            dispatch_kernel(index_mode, smem_padding, rows, radix_mode, log_n2, [&](auto variant, auto fft) {
                check_cuda(cudaFuncSetAttribute(pass2_rows<decltype(variant), decltype(fft)>,
                                               cudaFuncAttributeMaxDynamicSharedMemorySize, optin_limit),
                           "opt in pass 2 dynamic shared memory");
            });
        }
        workspace.allocate(bytes);
        roots1.upload(make_table(static_cast<size_t>(n1), static_cast<size_t>(n1), 1));
        roots2.upload(make_table(static_cast<size_t>(n2), static_cast<size_t>(n2), 1));
        cross_low.upload(make_table(n, cross_base, 1));
        cross_high.upload(make_table(n, n / cross_base, cross_base));
        // Pageable host-to-device copies can return after staging. Finish table
        // setup before execute is allowed to use an unrelated nonblocking stream.
        check_cuda(cudaStreamSynchronize(nullptr), "finish plan table initialization");
    }
};

Plan::Plan(size_t n, int batch, PlanOptions opts) : impl_(std::make_unique<Impl>(n, batch, opts)) {}
Plan::~Plan() = default;

void Plan::execute(const cuDoubleComplex* in, cuDoubleComplex* out, cudaStream_t stream) const {
    if (in == nullptr || out == nullptr) {
        throw std::runtime_error("fft2: execute input and output pointers must be non-null");
    }
    int device = -1;
    check_cuda(cudaGetDevice(&device), "get execution device");
    const Impl& p = *impl_;
    if (device != p.device) {
        throw std::runtime_error("fft2: execute must use the plan's creation device");
    }
    dispatch_kernel(p.index_mode, p.smem_padding, p.cols, p.radix_mode, p.log_n1, [&](auto variant, auto fft) {
        pass1_columns<decltype(variant), decltype(fft)><<<p.grid1, kThreads, p.shared1, stream>>>(
            in, p.workspace.data, p.n, p.batch, p.n1, p.n2, p.cols, p.log_n1, p.log_cols,
            p.cross_base, p.log_cross_base, p.roots1.data, p.cross_low.data, p.cross_high.data);
        check_cuda(cudaGetLastError(), "launch pass 1 (columns)");
    });
    dispatch_kernel(p.index_mode, p.smem_padding, p.rows, p.radix_mode, p.log_n2, [&](auto variant, auto fft) {
        pass2_rows<decltype(variant), decltype(fft)><<<p.grid2, kThreads, p.shared2, stream>>>(
            p.workspace.data, out, p.n, p.batch, p.n1, p.n2, p.rows, p.log_n2, p.log_rows, p.roots2.data);
        check_cuda(cudaGetLastError(), "launch pass 2 (rows)");
    });
}

size_t Plan::n() const { return impl_->n; }
int Plan::batch() const { return impl_->batch; }
int Plan::n1() const { return impl_->n1; }
int Plan::n2() const { return impl_->n2; }
size_t Plan::workspace_bytes() const { return impl_->bytes; }

std::string Plan::describe() const {
    const Impl& p = *impl_;
    std::ostringstream output;
    output << "fft2 N=" << p.n << " batch=" << p.batch << " N1=" << p.n1 << " N2=" << p.n2
           << " index_mode=" << p.index_mode << " smem_padding=" << p.smem_padding
           << " tile_policy=" << p.tile_policy << " radix_mode=" << p.radix_mode
           << " C=" << p.cols << " R=" << p.rows << " workspace_bytes=" << p.bytes
           << " pass1{grid=(" << p.grid1.x << ',' << p.grid1.y << ',' << p.grid1.z
           << "),block=(" << kThreads << ",1,1),lanes=" << p.cols << ",smem_bytes=" << p.shared1 << "}"
           << " pass2{grid=(" << p.grid2.x << ',' << p.grid2.y << ',' << p.grid2.z
           << "),block=(" << kThreads << ",1,1),lanes=" << p.rows << ",smem_bytes=" << p.shared2 << "}";
    return output.str();
}

}  // namespace fft2
