#pragma once

#include <cuComplex.h>
#include <cuda_runtime_api.h>

#include <cstddef>
#include <memory>
#include <string>

namespace fft2 {

struct PlanOptions {
    int n1 = 0;
    int tile_cols = 0;
    int tile_rows = 0;
    // The first three fields use 0 for the automatic split/tile policy.
    int index_mode = 0;    // 0 = v1 size_t division, 1 = u32 shift/mask.
    int smem_padding = 0;  // 0, 1 or 2 unused complex elements per shared row.
    // 0 = v1 fit; 1 = 32 KiB target, at least 2 lanes; uses 0 if 2 cannot fit.
    int tile_policy = 1;
    int radix_mode = -1;  // -1 = auto per pass; 0 = v1, 1 = radix-8, 2 = radix-16.
    int twiddle_mode = 0;  // 0 = __ldg roots, 1 = length-L roots staged in shared.
    int cross_mode = 0;    // 0 = high/low product, 1 = one length-N table.
    int io_mode = 0;       // 0 = v1 I/O, 1 = register I/O, 2 = fused boundary stages.
                          // Nonzero: register radix, lanes in {1, 2, 4, 8}, data tile <= 163 KiB.
};

class Plan {
public:
    // N = 2^16..2^24, batch >= 1. Allocates workspace and uploads tables only;
    // construction never reads or writes transform input/output data.
    Plan(size_t n, int batch, PlanOptions opts = {});
    ~Plan();
    Plan(const Plan&) = delete;
    Plan& operator=(const Plan&) = delete;

    // Forward, unnormalized, natural order; in == out is supported.
    // Asynchronous: the caller checks/synchronizes stream for execution errors.
    // A plan owns one workspace: its executions must not overlap in time.
    // Use the creation device and keep the plan alive until execution finishes.
    void execute(const cuDoubleComplex* in, cuDoubleComplex* out, cudaStream_t stream) const;

    size_t n() const;
    int batch() const;
    int n1() const;
    int n2() const;
    size_t workspace_bytes() const;
    std::string describe() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

}  // namespace fft2
