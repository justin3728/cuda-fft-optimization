#pragma once
#include "memory.cuh"
#include <cassert>

namespace measure {
inline void check_fft_iters(size_t n, int iterations) {
    const double maximum = 280.0 / std::log10(double(n));
    if (iterations < 1 || double(iterations) > maximum)
        throw std::runtime_error("--iters must be <= 280/log10(N) to avoid FP64 overflow");
    assert(double(iterations) <= maximum);
}
template<class Execute> double event_time(Execute&& execute, int iterations, cudaStream_t stream) {
    Event begin, end;
    T1_CUDA(cudaEventRecord(begin.value, stream));
    for (int i = 0; i < iterations; ++i) execute(stream);
    T1_CUDA(cudaEventRecord(end.value, stream));
    T1_CUDA(cudaEventSynchronize(end.value));
    float ms = 0;
    T1_CUDA(cudaEventElapsedTime(&ms, begin.value, end.value));
    if (!(ms > 0) || !std::isfinite(ms)) throw std::runtime_error("non-positive/non-finite CUDA event duration");
    return double(ms);
}
// The FFT sweep and both pass floors use this exact path. Restore and flush are
// ordered before the start event, on the same stream, and excluded from timing.
template<class Execute, class Restore>
Stats time_trials(Execute&& execute, Restore&& restore, L2Flush& flush, cudaStream_t stream,
                  const std::string& mode, int trials, int iterations, int warmup) {
    if (trials < 1 || warmup < 1 || iterations < 1 || (mode != "hot" && mode != "cold"))
        throw std::runtime_error("invalid timing parameters");
    for (int w = 0; w < warmup; ++w) { restore(stream); execute(stream); }
    T1_CUDA(cudaStreamSynchronize(stream));
    std::vector<double> samples;
    for (int trial = 0; trial < trials; ++trial) {
        restore(stream);
        if (mode == "cold") flush(stream);
        const int k = mode == "hot" ? iterations : 1;
        samples.push_back(event_time(execute, k, stream) / double(k));
    }
    return Stats(samples);
}
struct LongTiming { int iterations; double total_ms; double per_iteration_ms; };
template<class Execute> LongTiming time_at_least(Execute&& execute, cudaStream_t stream, double min_ms = 50) {
    execute(stream);
    T1_CUDA(cudaStreamSynchronize(stream));
    int iterations = 1;
    while (true) {
        const double elapsed = event_time(execute, iterations, stream);
        if (elapsed >= min_ms) return {iterations, elapsed, elapsed / double(iterations)};
        const double proposed = std::ceil(double(iterations) * std::min(16.0, 1.15 * min_ms / elapsed));
        if (proposed > 10000000) throw std::runtime_error("cannot obtain >= 50 ms of bandwidth samples");
        iterations = std::max(iterations + 1, int(proposed));
    }
}
} // namespace measure
