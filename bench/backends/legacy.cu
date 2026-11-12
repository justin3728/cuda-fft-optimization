#include "backend.hpp"
#include "../../fft_cuda.h"
#include <type_traits>

namespace measure {
class Legacy final : public FftBackend {
    fft_plan_cuda plan_{};
    bool ready_ = false;
    std::vector<cpxcuda> host_;
public:
    ~Legacy() override { if (ready_) fft_destroy_plan_cuda(plan_); }
    std::string name() const override { return "legacy"; }
    bool supports(size_t n, int batch, std::string* why) const override {
        if (!cufft_dimensions(n, batch, why)) return false;
        if (n > (size_t(1) << 20)) {
            if (why) *why = "legacy N > 2^20 exceeds the 1024-point shared array/twiddle table";
            return false;
        }
        if (size_t(batch) > size_t(std::numeric_limits<int>::max()) / n) {
            if (why) *why = "legacy API uses int offsets; N*batch must fit INT_MAX";
            return false;
        }
        return true;
    }
    void plan(size_t n, int batch) override {
        std::string reason;
        if (!supports(n, batch, &reason)) throw std::runtime_error(reason);
        if (ready_) throw std::runtime_error("legacy plan already exists");
        static_assert(sizeof(cpxcuda) == sizeof(cuDoubleComplex), "complex layout size");
        static_assert(offsetof(cpxcuda, im) == sizeof(double), "complex component layout");
        // The public API requires host input and output, and copies/uploads at
        // plan time. The same caller-owned host buffer is valid for both.
        host_.resize(elements(n, batch));
        plan_ = fft_plan_cuda_1d(int(n), batch, host_.data(), host_.data(), false);
        ready_ = true;
        // All measured inputs are restored to out_device with D2D by the driver.
        // Keep the legacy host batch loop and its shared temp_device unchanged.
    }
    cuDoubleComplex* buffer() override { return reinterpret_cast<cuDoubleComplex*>(plan_.out_device); }
    void execute(cudaStream_t stream) override { fft_execute_plan_cuda_async(plan_, stream); }
    void destroy() override {
        if (ready_) { fft_destroy_plan_cuda(plan_); ready_ = false; }
        host_.clear();
    }
};
std::unique_ptr<FftBackend> make_legacy() { return std::make_unique<Legacy>(); }
} // namespace measure
