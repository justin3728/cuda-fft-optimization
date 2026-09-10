#ifndef FFT_CUDA_H
#define FFT_CUDA_H

#include <cuda_runtime.h>

struct cpxcuda {
    double re, im;
};

struct fft_plan_cuda {
    int n, batch;
    int R, C;  // Four-step row-major matrix dimensions; R*C == n.
    cpxcuda *out, *out_device, *ws_device, *temp_device;
    bool reverse;
};

// Current benchmark covers forward, batch=1, power-of-two N=16..2^20.
// reverse=true and nonpositive/non-power-of-two lengths fail before buffer access.
// Larger sizes and other invalid arguments are not fully validated; see README.md.
// Host in/out buffers are caller-owned. Creation copies input to host out and
// uploads it; execution does not download results into host out.
fft_plan_cuda fft_plan_cuda_1d(int n, int batch, cpxcuda *in, cpxcuda *out, bool reverse);

// Enqueue all FFT device work, including required D2D copies, on stream.
// Caller owns the stream and must synchronize before reading/freeing results.
// Do not execute the same plan concurrently; its scratch buffers are shared.
void fft_execute_plan_cuda_async(fft_plan_cuda &plan, cudaStream_t stream);

// Compatibility wrapper: waits for device completion; performs no D2H copy.
void fft_execute_plan_cuda(fft_plan_cuda &plan);

void fft_destroy_plan_cuda(fft_plan_cuda &plan);

#endif
