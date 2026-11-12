#include "backend.hpp"

namespace measure {
class Cufft final : public FftBackend {
    cufftHandle plan_ = 0;
    DeviceBuffer<cuDoubleComplex> data_;
    cudaStream_t bound_stream_ = nullptr;
    bool stream_bound_ = false;
public:
    ~Cufft() override { if (plan_) cufftDestroy(plan_); }
    std::string name() const override { return "cufft"; }
    bool supports(size_t n, int batch, std::string* why) const override { return cufft_dimensions(n, batch, why); }
    void plan(size_t n, int batch) override {
        std::string reason;
        if (!supports(n, batch, &reason)) throw std::runtime_error(reason);
        data_.allocate(elements(n, batch));
        int dims[] = {int(n)};
        T1_CUFFT(cufftPlanMany(&plan_, 1, dims, dims, 1, int(n), dims, 1, int(n), CUFFT_Z2Z, batch));
    }
    cuDoubleComplex* buffer() override { return data_.get(); }
    void execute(cudaStream_t stream) override {
        // The first warmup binds the stream outside timing. Repeated timed
        // executions on that stream do not repeat the cuFFT setup API call.
        if (!stream_bound_ || stream != bound_stream_) {
            T1_CUFFT(cufftSetStream(plan_, stream));
            bound_stream_ = stream;
            stream_bound_ = true;
        }
        T1_CUFFT(cufftExecZ2Z(plan_, data_.get(), data_.get(), CUFFT_FORWARD));
    }
    void destroy() override {
        if (plan_) { T1_CUFFT(cufftDestroy(plan_)); plan_ = 0; }
        bound_stream_ = nullptr;
        stream_bound_ = false;
        data_.reset();
    }
};
std::unique_ptr<FftBackend> make_cufft() { return std::make_unique<Cufft>(); }
} // namespace measure
