#include "fft2.h"
#include "detail/tile_policy.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <vector>

namespace fft2 {
namespace {

constexpr unsigned int kThreads = 256;
constexpr size_t kDefaultSharedLimit = 48 * 1024;
// Largest shared tile any kernel is instantiated for (A100 opt-in limit).
constexpr size_t kMaxTileBytes = 163 * 1024;
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

// Shared memory holds a tile as [element][lane]: the lanes of one element are adjacent.
__device__ __forceinline__ size_t shared_index(size_t element, size_t lane, int lanes) {
    return element * static_cast<size_t>(lanes) + lane;
}

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

// One pass over a tile of Lanes FFTs of length 2^LogLength, radix 2^Bits.
// The first radix stage runs on values loaded from global memory straight into
// registers, and the last radix stage runs in registers right before the global
// store; only the stages in between exchange data through shared memory.
template <int LogLength, int Bits, int Lanes>
struct TilePass {
    static constexpr int length = 1 << LogLength;
    static constexpr int first_bits = Bits;
    static constexpr int first_radix = 1 << first_bits;
    static constexpr int last_bits = (LogLength - 1) % Bits + 1;
    static constexpr int last_radix = 1 << last_bits;
    static constexpr int loads = (length * Lanes / first_radix + kThreads - 1) / kThreads;
    static constexpr int stores = (length * Lanes / last_radix + kThreads - 1) / kThreads;

    // Shared radix stages [Done, End). The recursion forms the complete stage
    // plan at compile time, including a smaller final radix.
    template <int Done, int End>
    __device__ static __forceinline__ void stage(cuDoubleComplex* shared, const cuDoubleComplex* roots) {
        constexpr int bits = LogLength - Done < Bits ? LogLength - Done : Bits;
        constexpr int radix = 1 << bits;
        constexpr int previous = 1 << Done;
        constexpr int span = previous * radix;
        const size_t width = static_cast<size_t>(Lanes);
        const size_t count = (length / radix) * width;
        for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
            const size_t butterfly = flat / width;
            const size_t lane = flat % width;
            const size_t j = butterfly % static_cast<size_t>(previous);
            const size_t start = butterfly / static_cast<size_t>(previous) * span + j;
            cuDoubleComplex v[radix];
            #pragma unroll
            for (int t = 0; t < radix; ++t) {
                // Shared input is bit reversed within each radix. External
                // twiddles use the natural (reversed t) sub-FFT number.
                const size_t exponent = reverse_index(static_cast<size_t>(t), bits) * j * (length / span);
                v[t] = mul(shared[shared_index(start + t * previous, lane, Lanes)],
                           read_twiddle(roots, exponent));
            }
            // No shared access or barrier between these internal DIT stages.
            register_butterfly(v);
            #pragma unroll
            for (int t = 0; t < radix; ++t) {
                shared[shared_index(start + t * previous, lane, Lanes)] = v[t];
            }
        }
        // Every butterfly reads/writes its own disjoint set: one barrier per stage.
        __syncthreads();
        if constexpr (Done + bits < End) { stage<Done + bits, End>(shared, roots); }
    }

    template <bool Columns>
    __device__ static __forceinline__ int input_map(int group, int t, int& element, int& lane) {
        const int flat = threadIdx.x + group * kThreads;
        const int q = Columns ? flat / Lanes : flat % (length / first_radix);
        lane = Columns ? flat % Lanes : flat / (length / first_radix);
        element = q + reverse_index(t, first_bits) * (length / first_radix);
        return flat;
    }

    __device__ static __forceinline__ int output_map(int group, int t, int& element, int& lane) {
        const int flat = threadIdx.x + group * kThreads;
        lane = flat % Lanes;
        element = flat / Lanes + t * (length / last_radix);
        return flat;
    }

    // Columns (pass 1): the tile is Lanes adjacent columns of a row-major
    // N1 x N2 array; results are multiplied by the cross twiddle W_N^(column*k1).
    // Rows (pass 2): the tile is Lanes contiguous rows; results are written
    // transposed so the output is in natural order.
    template <bool Columns>
    __device__ static __forceinline__ void execute(
        const cuDoubleComplex* input, cuDoubleComplex* output, cuDoubleComplex* shared,
        int other_length, const cuDoubleComplex* roots,
        size_t n = 0, size_t cross_base = 1,
        const cuDoubleComplex* cross_low = nullptr, const cuDoubleComplex* cross_high = nullptr) {
        const int first = blockIdx.x * Lanes;
        cuDoubleComplex v[loads][first_radix];
        // Fully unrolled: every global load is issued before any shared store.
        #pragma unroll
        for (int g = 0; g < loads; ++g) {
            #pragma unroll
            for (int t = 0; t < first_radix; ++t) {
                int element, lane;
                const int flat = input_map<Columns>(g, t, element, lane);
                const int offset = Columns ? element * other_length + first + lane
                                           : (first + lane) * length + element;
                v[g][t] = flat < length * Lanes / first_radix && first + lane < other_length
                    ? input[offset] : make_cuDoubleComplex(0.0, 0.0);
            }
        }
        #pragma unroll
        for (int g = 0; g < loads; ++g) {
            register_butterfly(v[g]);
            #pragma unroll
            for (int t = 0; t < first_radix; ++t) {
                int element, lane;
                const int flat = input_map<Columns>(g, t, element, lane);
                // q is natural on load; shared uses the bit-reversed sub-FFT.
                const int destination =
                    reverse_index(element % (length / first_radix), LogLength - first_bits) * first_radix + t;
                if (flat < length * Lanes / first_radix) {
                    shared[shared_index(size_t(destination), size_t(lane), Lanes)] = v[g][t];
                }
            }
        }
        __syncthreads();
        if constexpr (Bits < LogLength - last_bits) {
            stage<Bits, LogLength - last_bits>(shared, roots);
        }
        cuDoubleComplex result[stores][last_radix];
        // Read the entire output register set before any global store.
        #pragma unroll
        for (int g = 0; g < stores; ++g) {
            #pragma unroll
            for (int t = 0; t < last_radix; ++t) {
                int element, lane;
                const int flat = output_map(g, t, element, lane);
                result[g][t] = flat < length * Lanes / last_radix
                    ? shared[shared_index(size_t(element), size_t(lane), Lanes)] : make_cuDoubleComplex(0.0, 0.0);
                if (flat < length * Lanes / last_radix) {
                    result[g][t] = mul(result[g][t], read_twiddle(roots,
                        reverse_index(t, last_bits) * (flat / Lanes)));
                }
            }
        }
        #pragma unroll
        for (int g = 0; g < stores; ++g) {
            register_butterfly(result[g]);
            #pragma unroll
            for (int t = 0; t < last_radix; ++t) {
                int element, lane;
                output_map(g, t, element, lane);
                if constexpr (Columns) {
                    if (first + lane < other_length) {
                        // W_N^e = W_N^(e / base * base) * W_N^(e % base): two short tables.
                        const size_t exponent = size_t(first + lane) * size_t(element) % n;
                        const cuDoubleComplex cross = mul(read_twiddle(cross_high, exponent / cross_base),
                                                          read_twiddle(cross_low, exponent % cross_base));
                        result[g][t] = mul(result[g][t], cross);
                    }
                }
            }
        }
        #pragma unroll
        for (int g = 0; g < stores; ++g) {
            #pragma unroll
            for (int t = 0; t < last_radix; ++t) {
                int element, lane;
                const int flat = output_map(g, t, element, lane);
                if (flat < length * Lanes / last_radix && first + lane < other_length) {
                    const int offset = Columns ? element * other_length + first + lane
                                               : first + lane + other_length * element;
                    output[offset] = result[g][t];
                }
            }
        }
    }
};

template <int L, int B, int Lanes = 1, typename Action>
void dispatch_lanes(int lanes, const Action& action) {
    if (lanes == Lanes) { action(TilePass<L, B, Lanes>{}); return; }
    // Do not generate register arrays for tiles that cannot fit any target.
    if constexpr (Lanes < 8 && (Lanes * 2) * (1 << L) * sizeof(cuDoubleComplex) <= kMaxTileBytes) {
        dispatch_lanes<L, B, Lanes * 2>(lanes, action);
    } else {
        throw std::runtime_error("fft2: lanes must be 1, 2, 4 or 8 and the tile <= 163 KiB");
    }
}

template <int B, typename Action>
void dispatch_length(int log_length, int lanes, const Action& action) {
    switch (log_length) {
        case 8: dispatch_lanes<8, B>(lanes, action); break;
        case 9: dispatch_lanes<9, B>(lanes, action); break;
        case 10: dispatch_lanes<10, B>(lanes, action); break;
        case 11: dispatch_lanes<11, B>(lanes, action); break;
        case 12: dispatch_lanes<12, B>(lanes, action); break;
        default: throw std::runtime_error("fft2: pass length must be 256..4096");
    }
}

template <typename Action>
void dispatch_pass(int log_length, int radix_bits, int lanes, const Action& action) {
    if (radix_bits == 4) { dispatch_length<4>(log_length, lanes, action); }
    else { dispatch_length<3>(log_length, lanes, action); }
}

template <typename Pass>
__global__ void pass1_columns(const cuDoubleComplex* __restrict__ input,
                              cuDoubleComplex* __restrict__ workspace, size_t n, int batch, int n2,
                              size_t cross_base, const cuDoubleComplex* __restrict__ roots,
                              const cuDoubleComplex* __restrict__ cross_low,
                              const cuDoubleComplex* __restrict__ cross_high) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;  // Uniform for the whole block, before any barrier.
    }
    extern __shared__ cuDoubleComplex shared[];
    Pass::template execute<true>(input + batch_index * n, workspace + batch_index * n, shared,
                                 n2, roots, n, cross_base, cross_low, cross_high);
}

template <typename Pass>
__global__ void pass2_rows(const cuDoubleComplex* __restrict__ workspace,
                           cuDoubleComplex* __restrict__ output, size_t n, int batch, int n1,
                           const cuDoubleComplex* __restrict__ roots) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;
    }
    extern __shared__ cuDoubleComplex shared[];
    Pass::template execute<false>(workspace + batch_index * n, output + batch_index * n, shared, n1, roots);
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
    int radix1;  // log2 of the pass-1 radix
    int radix2;
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

    Impl(size_t requested_n, int requested_batch) : n(requested_n), batch(requested_batch) {
        if (!power_of_two(n) || n < (size_t{1} << 16) || n > (size_t{1} << 24)) {
            throw std::runtime_error("fft2: N must be a power of two in [2^16, 2^24]");
        }
        if (batch < 1) {
            throw std::runtime_error("fft2: batch must be >= 1");
        }
        if (n > std::numeric_limits<size_t>::max() / static_cast<size_t>(batch)
            || n * static_cast<size_t>(batch) > std::numeric_limits<size_t>::max() / sizeof(cuDoubleComplex)) {
            throw std::runtime_error("fft2: N * batch byte count overflows size_t");
        }
        const int log_n = integer_log2(n);
        log_n1 = log_n / 2;
        log_n2 = log_n - log_n1;
        n1 = 1 << log_n1;
        n2 = 1 << log_n2;
        const int log_cross_base = (log_n + 1) / 2;
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
        cols = choose_tile(n1, n2, limit);
        rows = choose_tile(n2, n1, limit);
        radix1 = detail::radix_bits(n1, cols, kThreads);
        radix2 = detail::radix_bits(n2, rows, kThreads);
        shared1 = shared_bytes(n1, cols);
        shared2 = shared_bytes(n2, rows);

        int max_y = 0;
        int max_z = 0;
        check_cuda(cudaDeviceGetAttribute(&max_y, cudaDevAttrMaxGridDimY, device), "query grid.y limit");
        check_cuda(cudaDeviceGetAttribute(&max_z, cudaDevAttrMaxGridDimZ, device), "query grid.z limit");
        const size_t grid_y = std::min(static_cast<size_t>(batch), static_cast<size_t>(max_y));
        const size_t grid_z = (static_cast<size_t>(batch) + grid_y - 1) / grid_y;
        if (grid_z > static_cast<size_t>(max_z)) {
            throw std::runtime_error("fft2: batch exceeds device grid dimensions");
        }
        grid1 = dim3(static_cast<unsigned int>(n2 / cols), static_cast<unsigned int>(grid_y),
                     static_cast<unsigned int>(grid_z));
        grid2 = dim3(static_cast<unsigned int>(n1 / rows), static_cast<unsigned int>(grid_y),
                     static_cast<unsigned int>(grid_z));

        if (limit > kDefaultSharedLimit) {
            // Set the full device limit, never a smaller plan's requirement:
            // constructing another plan must not invalidate an existing plan.
            dispatch_pass(log_n1, radix1, cols, [&](auto pass) {
                check_cuda(cudaFuncSetAttribute(pass1_columns<decltype(pass)>,
                                               cudaFuncAttributeMaxDynamicSharedMemorySize, optin_limit),
                           "opt in pass 1 dynamic shared memory");
            });
            dispatch_pass(log_n2, radix2, rows, [&](auto pass) {
                check_cuda(cudaFuncSetAttribute(pass2_rows<decltype(pass)>,
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

Plan::Plan(size_t n, int batch) : impl_(std::make_unique<Impl>(n, batch)) {}
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
    dispatch_pass(p.log_n1, p.radix1, p.cols, [&](auto pass) {
        pass1_columns<decltype(pass)><<<p.grid1, kThreads, p.shared1, stream>>>(
            in, p.workspace.data, p.n, p.batch, p.n2, p.cross_base,
            p.roots1.data, p.cross_low.data, p.cross_high.data);
        check_cuda(cudaGetLastError(), "launch pass 1 (columns)");
    });
    dispatch_pass(p.log_n2, p.radix2, p.rows, [&](auto pass) {
        pass2_rows<decltype(pass)><<<p.grid2, kThreads, p.shared2, stream>>>(
            p.workspace.data, out, p.n, p.batch, p.n1, p.roots2.data);
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
           << " radix=(" << (1 << p.radix1) << ',' << (1 << p.radix2) << ')'
           << " C=" << p.cols << " R=" << p.rows << " workspace_bytes=" << p.bytes
           << " pass1{grid=(" << p.grid1.x << ',' << p.grid1.y << ',' << p.grid1.z
           << "),block=(" << kThreads << ",1,1),lanes=" << p.cols << ",smem_bytes=" << p.shared1 << "}"
           << " pass2{grid=(" << p.grid2.x << ',' << p.grid2.y << ',' << p.grid2.z
           << "),block=(" << kThreads << ",1,1),lanes=" << p.rows << ",smem_bytes=" << p.shared2 << "}";
    return output.str();
}

}  // namespace fft2
