#pragma once

#include <cuda_runtime.h>
#include <cuComplex.h>
#include <cufft.h>
#include <algorithm>
#include <cmath>
#include <cctype>
#include <cstddef>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace measure {
inline void cuda_check(cudaError_t result, const char* call) {
    if (result != cudaSuccess)
        throw std::runtime_error(std::string(call) + ": " + cudaGetErrorString(result));
}
inline void cufft_check(cufftResult result, const char* call) {
    if (result != CUFFT_SUCCESS)
        throw std::runtime_error(std::string(call) + ": cuFFT error " + std::to_string(result));
}
#define T1_CUDA(call) ::measure::cuda_check((call), #call)
#define T1_CUFFT(call) ::measure::cufft_check((call), #call)

inline size_t elements(size_t n, int batch) {
    if (n < 2 || (n & (n - 1)) || batch < 1 ||
        n > std::numeric_limits<size_t>::max() / (2 * sizeof(cuDoubleComplex)) / size_t(batch))
        throw std::runtime_error("N must be a power of two >= 2; batch/byte count must fit size_t");
    return n * size_t(batch);
}
template<class T> class DeviceBuffer {
    T* ptr_ = nullptr;
public:
    explicit DeviceBuffer(size_t count = 0) { if (count) allocate(count); }
    ~DeviceBuffer() { if (ptr_) cudaFree(ptr_); }
    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
    void allocate(size_t count) {
        if (ptr_) throw std::runtime_error("DeviceBuffer already allocated");
        if (count > std::numeric_limits<size_t>::max() / sizeof(T))
            throw std::runtime_error("device allocation size overflow");
        T1_CUDA(cudaMalloc(reinterpret_cast<void**>(&ptr_), count * sizeof(T)));
    }
    T* get() const { return ptr_; }
    void reset() { if (ptr_) { T1_CUDA(cudaFree(ptr_)); ptr_ = nullptr; } }
};
struct Stream {
    cudaStream_t value = nullptr;
    Stream() { T1_CUDA(cudaStreamCreateWithFlags(&value, cudaStreamNonBlocking)); }
    ~Stream() { if (value) cudaStreamDestroy(value); }
    Stream(const Stream&) = delete;
    Stream& operator=(const Stream&) = delete;
};
struct Event {
    cudaEvent_t value = nullptr;
    Event() { T1_CUDA(cudaEventCreate(&value)); }
    ~Event() { if (value) cudaEventDestroy(value); }
    Event(const Event&) = delete;
    Event& operator=(const Event&) = delete;
};
inline cudaDeviceProp device_properties() {
    int device = 0;
    T1_CUDA(cudaGetDevice(&device));
    cudaDeviceProp props{};
    T1_CUDA(cudaGetDeviceProperties(&props, device));
    return props;
}
inline size_t l2_bytes() {
    int device = 0, bytes = 0;
    T1_CUDA(cudaGetDevice(&device));
    T1_CUDA(cudaDeviceGetAttribute(&bytes, cudaDevAttrL2CacheSize, device));
    if (bytes <= 0) throw std::runtime_error("GPU did not report a positive L2 size; cannot define cold timing");
    return size_t(bytes);
}
inline std::filesystem::path result_root(const std::string& tag) {
    if (tag.empty() || !std::isalnum(static_cast<unsigned char>(tag.front())) ||
        tag.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-") != std::string::npos)
        throw std::runtime_error("--tag must start with an alphanumeric and contain only letters, digits, _, ., -");
    const auto path = std::filesystem::path("results") / tag;
    std::filesystem::create_directories(path);
    return path;
}
inline std::ofstream new_output(const std::filesystem::path& path) {
    if (std::filesystem::exists(path)) throw std::runtime_error("refusing to overwrite " + path.string());
    std::filesystem::create_directories(path.parent_path());
    std::ofstream out(path);
    if (!out) throw std::runtime_error("cannot open " + path.string());
    out.exceptions(std::ios::badbit | std::ios::failbit);
    out << std::setprecision(17);
    return out;
}
inline std::string csv(const std::string& value) {
    std::string result = "\"";
    for (char c : value) { if (c == '\"') result += '\"'; result += (c == '\n' || c == '\r') ? ' ' : c; }
    return result + '\"';
}
inline std::string json(const std::string& value) {
    std::string result = "\"";
    for (unsigned char c : value) {
        if (c == '\"' || c == '\\') { result += '\\'; result += char(c); }
        else if (c == '\n') result += "\\n";
        else if (c == '\r') result += "\\r";
        else if (c == '\t') result += "\\t";
        else if (c < 32) throw std::runtime_error("control character in JSON string");
        else result += char(c);
    }
    return result + '\"';
}
inline double quantile(std::vector<double> values, double q) {
    if (values.empty()) throw std::runtime_error("no timing samples");
    std::sort(values.begin(), values.end());
    const double at = q * double(values.size() - 1);
    const size_t lo = size_t(at), hi = std::min(lo + 1, values.size() - 1);
    return values[lo] + (values[hi] - values[lo]) * (at - double(lo));
}
struct Stats {
    double median, minimum, p10, p90;
    explicit Stats(const std::vector<double>& samples)
        : median(quantile(samples, .5)), minimum(quantile(samples, 0)),
          p10(quantile(samples, .1)), p90(quantile(samples, .9)) {}
};
inline void write_stats(std::ostream& out, const Stats& s) {
    out << s.median << ',' << s.minimum << ',' << s.p10 << ',' << s.p90;
}
} // namespace measure
