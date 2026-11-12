#pragma once
#include "../common/runtime.cuh"
#include "../../fft2/fft2.h"
#include <memory>

namespace measure {
struct FftBackend {
    virtual ~FftBackend() = default;
    virtual std::string name() const = 0;
    virtual bool supports(size_t n, int batch, std::string* why) const = 0;
    virtual void plan(size_t n, int batch) = 0;
    virtual cuDoubleComplex* buffer() = 0;
    virtual cuDoubleComplex* output() { return buffer(); }
    virtual std::string detail() const { return ""; }
    virtual void execute(cudaStream_t stream) = 0;
    virtual void destroy() = 0;
    virtual void export_kernels(const std::filesystem::path&) {
        throw std::runtime_error("kernel export is only available for VkFFT");
    }
};
std::unique_ptr<FftBackend> make_cufft();
std::unique_ptr<FftBackend> make_vkfft(bool keep_code = false);
std::unique_ptr<FftBackend> make_fft2(bool out_of_place = false);
inline std::string fft2_name(bool out_of_place = false) { return out_of_place ? "fft2_oop" : "fft2"; }
inline std::unique_ptr<FftBackend> backend(const std::string& name, bool keep_code = false, bool out_of_place = false) {
    // Add the next implementation here; the driver does not know backend internals.
    if (name == "cufft") return make_cufft();
    if (name == "vkfft") return make_vkfft(keep_code);
    if (name == "fft2") return make_fft2(out_of_place);
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
