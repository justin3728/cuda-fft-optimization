#pragma once
#include "../common/runtime.cuh"
#include <memory>

namespace measure {
struct FftBackend {
    virtual ~FftBackend() = default;
    virtual std::string name() const = 0;
    virtual bool supports(size_t n, int batch, std::string* why) const = 0;
    virtual void plan(size_t n, int batch) = 0;
    virtual cuDoubleComplex* buffer() = 0;
    virtual void execute(cudaStream_t stream) = 0;
    virtual void destroy() = 0;
    virtual void export_kernels(const std::filesystem::path&) {
        throw std::runtime_error("kernel export is only available for VkFFT");
    }
};
std::unique_ptr<FftBackend> make_legacy();
std::unique_ptr<FftBackend> make_cufft();
std::unique_ptr<FftBackend> make_vkfft(bool keep_code = false);
inline std::unique_ptr<FftBackend> backend(const std::string& name, bool keep_code = false) {
    // Add the next implementation here; the driver does not know backend internals.
    if (name == "legacy") return make_legacy();
    if (name == "cufft") return make_cufft();
    if (name == "vkfft") return make_vkfft(keep_code);
    throw std::runtime_error("unknown implementation: " + name);
}
inline bool cufft_dimensions(size_t n, int batch, std::string* why) {
    if (n < 2 || (n & (n - 1)) || n > size_t(std::numeric_limits<int>::max()) || batch < 1) {
        if (why) *why = "requires power-of-two N >= 2, N <= INT_MAX, batch > 0";
        return false;
    }
    return true;
}
} // namespace measure
