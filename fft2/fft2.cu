#include "fft2.h"

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
// Padding hook: shared[element * (lanes + padding) + lane]. If changed, both
// shared_index() and shared_bytes() use it. The reference uses padding == 0.
constexpr size_t kSharedPadding = 0;

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

size_t shared_bytes(int length, int lanes) {
    return static_cast<size_t>(length) * (static_cast<size_t>(lanes) + kSharedPadding)
           * sizeof(cuDoubleComplex);
}

int choose_tile(int length, int other_length, int requested, size_t limit, const char* name) {
    if (requested < 0) {
        throw std::runtime_error(std::string("fft2: ") + name + " must be nonnegative (0 = automatic)");
    }
    int lanes = requested == 0 ? std::min(8, other_length) : requested;
    if (requested == 0) {
        while (lanes > 0 && shared_bytes(length, lanes) > limit) {
            lanes /= 2;
        }
    }
    if (lanes == 0 || lanes > other_length || shared_bytes(length, lanes) > limit) {
        std::ostringstream message;
        message << "fft2: " << name << "=" << requested << " for length=" << length
                << " exceeds the dimension or device opt-in shared-memory limit=" << limit
                << " bytes (one FFT requires " << shared_bytes(length, 1) << " bytes)";
        throw std::runtime_error(message.str());
    }
    return lanes;
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

__device__ __forceinline__ size_t shared_index(size_t element, size_t lane, int lanes) {
    return element * (static_cast<size_t>(lanes) + kSharedPadding) + lane;
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

__device__ __forceinline__ cuDoubleComplex read_twiddle(const cuDoubleComplex* table, size_t index) {
    return make_cuDoubleComplex(__ldg(&table[index].x), __ldg(&table[index].y));
}

__device__ __forceinline__ size_t reverse_index(size_t index, int log_length) {
    return static_cast<size_t>(__brev(static_cast<unsigned int>(index)) >> (32 - log_length));
}

// On entry shared[element, lane] already contains bit-reversed input.
// Each thread holds four values and fuses two radix-2 DIT stages into one
// radix-4 stage. Butterfly sets are disjoint; a block barrier follows each stage.
// Formulas are independently exercised by reference.block_fft().
__device__ void block_fft(cuDoubleComplex* shared, int length, int lanes, int log_length,
                          const cuDoubleComplex* roots) {
    const size_t width = static_cast<size_t>(lanes);
    const size_t fft_length = static_cast<size_t>(length);
    for (size_t span = 4; span <= fft_length; span *= 4) {
        const size_t quarter = span / 4;
        const size_t count = (fft_length / 4) * width;
        for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
            const size_t butterfly = flat / width;
            const size_t lane = flat % width;
            const size_t j = butterfly % quarter;
            const size_t start = (butterfly / quarter) * span + j;
            const size_t exponent = j * (fft_length / span);
            const cuDoubleComplex w1 = read_twiddle(roots, exponent);
            const cuDoubleComplex w2 = read_twiddle(roots, 2 * exponent);
            const cuDoubleComplex a0 = shared[shared_index(start, lane, lanes)];
            const cuDoubleComplex a1 = mul(shared[shared_index(start + quarter, lane, lanes)], w2);
            const cuDoubleComplex a2 = shared[shared_index(start + 2 * quarter, lane, lanes)];
            const cuDoubleComplex a3 = mul(shared[shared_index(start + 3 * quarter, lane, lanes)], w2);
            const cuDoubleComplex u0 = add(a0, a1);
            const cuDoubleComplex u1 = sub(a0, a1);
            const cuDoubleComplex u2 = mul(add(a2, a3), w1);
            const cuDoubleComplex rotated = mul(sub(a2, a3), w1);
            const cuDoubleComplex u3 = make_cuDoubleComplex(rotated.y, -rotated.x);  // -i * rotated
            shared[shared_index(start, lane, lanes)] = add(u0, u2);
            shared[shared_index(start + quarter, lane, lanes)] = add(u1, u3);
            shared[shared_index(start + 2 * quarter, lane, lanes)] = sub(u0, u2);
            shared[shared_index(start + 3 * quarter, lane, lanes)] = sub(u1, u3);
        }
        __syncthreads();
    }
    if ((log_length & 1) != 0) {
        const size_t half = fft_length / 2;
        for (size_t flat = threadIdx.x; flat < half * width; flat += blockDim.x) {
            const size_t j = flat / width;
            const size_t lane = flat % width;
            const cuDoubleComplex a = shared[shared_index(j, lane, lanes)];
            const cuDoubleComplex b = mul(shared[shared_index(j + half, lane, lanes)],
                                          read_twiddle(roots, j));
            shared[shared_index(j, lane, lanes)] = add(a, b);
            shared[shared_index(j + half, lane, lanes)] = sub(a, b);
        }
        __syncthreads();
    }
}

__global__ void pass1_columns(const cuDoubleComplex* __restrict__ input,
                               cuDoubleComplex* __restrict__ workspace, size_t n, int batch,
                               int n1, int n2, int cols, int log_n1, size_t cross_base,
                               const cuDoubleComplex* __restrict__ roots,
                               const cuDoubleComplex* __restrict__ cross_low,
                               const cuDoubleComplex* __restrict__ cross_high) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;  // Uniform for the whole block, before any barrier.
    }
    extern __shared__ cuDoubleComplex shared[];
    const size_t base = batch_index * n;
    const size_t first_col = static_cast<size_t>(blockIdx.x) * static_cast<size_t>(cols);
    const size_t width = static_cast<size_t>(cols);
    const size_t count = static_cast<size_t>(n1) * width;
    // Reference pass 1: flat = n1_index * C + lane.
    for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const size_t element = flat / width;
        const size_t lane = flat % width;
        const size_t column = first_col + lane;
        const cuDoubleComplex value = column < static_cast<size_t>(n2)
            ? input[base + element * static_cast<size_t>(n2) + column]
            : make_cuDoubleComplex(0.0, 0.0);
        shared[shared_index(reverse_index(element, log_n1), lane, cols)] = value;
    }
    __syncthreads();
    block_fft(shared, n1, cols, log_n1, roots);
    for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const size_t k1 = flat / width;
        const size_t lane = flat % width;
        const size_t column = first_col + lane;
        if (column < static_cast<size_t>(n2)) {
            const uint64_t exponent = (static_cast<uint64_t>(column) * static_cast<uint64_t>(k1))
                                      % static_cast<uint64_t>(n);
            const cuDoubleComplex cross = mul(read_twiddle(cross_high, exponent / cross_base),
                                              read_twiddle(cross_low, exponent % cross_base));
            workspace[base + k1 * static_cast<size_t>(n2) + column] =
                mul(shared[shared_index(k1, lane, cols)], cross);
        }
    }
}

__global__ void pass2_rows(const cuDoubleComplex* __restrict__ workspace,
                           cuDoubleComplex* __restrict__ output, size_t n, int batch,
                           int n1, int n2, int rows, int log_n2,
                           const cuDoubleComplex* __restrict__ roots) {
    const size_t batch_index = static_cast<size_t>(blockIdx.y) + static_cast<size_t>(gridDim.y) * blockIdx.z;
    if (batch_index >= static_cast<size_t>(batch)) {
        return;
    }
    extern __shared__ cuDoubleComplex shared[];
    const size_t base = batch_index * n;
    const size_t first_row = static_cast<size_t>(blockIdx.x) * static_cast<size_t>(rows);
    const size_t width = static_cast<size_t>(rows);
    const size_t count = static_cast<size_t>(n2) * width;
    // Reference pass 2 LOAD: flat = lane * N2 + n2_index (contiguous rows).
    for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const size_t lane = flat / static_cast<size_t>(n2);
        const size_t element = flat % static_cast<size_t>(n2);
        const size_t row = first_row + lane;
        const cuDoubleComplex value = row < static_cast<size_t>(n1)
            ? workspace[base + row * static_cast<size_t>(n2) + element]
            : make_cuDoubleComplex(0.0, 0.0);
        shared[shared_index(reverse_index(element, log_n2), lane, rows)] = value;
    }
    __syncthreads();
    block_fft(shared, n2, rows, log_n2, roots);
    // Reference pass 2 STORE: flat = k2 * R + lane (adjacent output k1's).
    for (size_t flat = threadIdx.x; flat < count; flat += blockDim.x) {
        const size_t k2 = flat / width;
        const size_t lane = flat % width;
        const size_t row = first_row + lane;
        if (row < static_cast<size_t>(n1)) {
            output[base + row + static_cast<size_t>(n1) * k2] = shared[shared_index(k2, lane, rows)];
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
        cross_base = size_t{1} << ((log_n + 1) / 2);
        bytes = n * static_cast<size_t>(batch) * sizeof(cuDoubleComplex);

        check_cuda(cudaGetDevice(&device), "get plan device");
        int optin_limit = 0;
        check_cuda(cudaDeviceGetAttribute(&optin_limit, cudaDevAttrMaxSharedMemoryPerBlockOptin, device),
                   "query opt-in shared-memory limit");
        if (optin_limit <= 0) {
            throw std::runtime_error("fft2: device reports no opt-in shared memory");
        }
        const size_t limit = static_cast<size_t>(optin_limit);
        cols = choose_tile(n1, n2, opts.tile_cols, limit, "tile_cols");
        rows = choose_tile(n2, n1, opts.tile_rows, limit, "tile_rows");
        shared1 = shared_bytes(n1, cols);
        shared2 = shared_bytes(n2, rows);

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
            check_cuda(cudaFuncSetAttribute(pass1_columns, cudaFuncAttributeMaxDynamicSharedMemorySize, optin_limit),
                       "opt in pass 1 dynamic shared memory");
            check_cuda(cudaFuncSetAttribute(pass2_rows, cudaFuncAttributeMaxDynamicSharedMemorySize, optin_limit),
                       "opt in pass 2 dynamic shared memory");
        }
        workspace.allocate(bytes);
        roots1.upload(make_table(static_cast<size_t>(n1), static_cast<size_t>(n1), 1));
        roots2.upload(make_table(static_cast<size_t>(n2), static_cast<size_t>(n2), 1));
        cross_low.upload(make_table(n, cross_base, 1));
        cross_high.upload(make_table(n, n / cross_base, cross_base));
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
    pass1_columns<<<p.grid1, kThreads, p.shared1, stream>>>(
        in, p.workspace.data, p.n, p.batch, p.n1, p.n2, p.cols, p.log_n1, p.cross_base,
        p.roots1.data, p.cross_low.data, p.cross_high.data);
    check_cuda(cudaGetLastError(), "launch pass 1 (columns)");
    pass2_rows<<<p.grid2, kThreads, p.shared2, stream>>>(
        p.workspace.data, out, p.n, p.batch, p.n1, p.n2, p.rows, p.log_n2, p.roots2.data);
    check_cuda(cudaGetLastError(), "launch pass 2 (rows)");
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
           << " C=" << p.cols << " R=" << p.rows << " workspace_bytes=" << p.bytes
           << " pass1{grid=(" << p.grid1.x << ',' << p.grid1.y << ',' << p.grid1.z
           << "),block=(" << kThreads << ",1,1),smem_bytes=" << p.shared1 << "}"
           << " pass2{grid=(" << p.grid2.x << ',' << p.grid2.y << ',' << p.grid2.z
           << "),block=(" << kThreads << ",1,1),smem_bytes=" << p.shared2 << "}";
    return output.str();
}

}  // namespace fft2
