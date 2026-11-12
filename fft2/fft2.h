#pragma once

#include <cuComplex.h>
#include <cuda_runtime_api.h>

#include <cstddef>
#include <memory>
#include <string>

namespace fft2 {

// Double-precision complex-to-complex forward FFT in two passes (N = N1 x N2):
// pass 1 transforms columns and applies the cross twiddles, pass 2 transforms
// rows. Each pass reads and writes the array once.
class Plan {
public:
    // N = 2^16..2^24, batch >= 1. Allocates workspace and uploads tables only;
    // construction never reads or writes transform input/output data.
    Plan(size_t n, int batch);
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
