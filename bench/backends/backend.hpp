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
std::unique_ptr<FftBackend> make_legacy();
std::unique_ptr<FftBackend> make_cufft();
std::unique_ptr<FftBackend> make_vkfft(bool keep_code = false);
std::unique_ptr<FftBackend> make_fft2(fft2::PlanOptions options = {}, bool out_of_place = false);
inline std::string fft2_name(fft2::PlanOptions options, bool out_of_place = false) {
    std::string name = "fft2[n1=" + std::to_string(options.n1) + ",c=" + std::to_string(options.tile_cols) +
                       ",r=" + std::to_string(options.tile_rows);
    if (options.index_mode != 0) name += ",im=" + std::to_string(options.index_mode);
    if (options.smem_padding != 0) name += ",pad=" + std::to_string(options.smem_padding);
    if (options.tile_policy != 0) name += ",tp=" + std::to_string(options.tile_policy);
    if (options.radix_mode != 0) name += ",rx=" + std::to_string(options.radix_mode);
    if (out_of_place) name += ",oop=1";
    return name + "]";
}
inline std::unique_ptr<FftBackend> backend(const std::string& name, bool keep_code = false,
                                         fft2::PlanOptions options = {}, bool out_of_place = false) {
    // Add the next implementation here; the driver does not know backend internals.
    if (name == "legacy") return make_legacy();
    if (name == "cufft") return make_cufft();
    if (name == "vkfft") return make_vkfft(keep_code);
    if (name == "fft2") return make_fft2(options, out_of_place);
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
