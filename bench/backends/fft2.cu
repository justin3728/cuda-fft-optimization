#include "backend.hpp"

namespace measure {
class Fft2 final : public FftBackend {
    bool out_of_place_;
    DeviceBuffer<cuDoubleComplex> data_, output_;
    std::unique_ptr<fft2::Plan> plan_;
public:
    explicit Fft2(bool out_of_place) : out_of_place_(out_of_place) {}
    std::string name() const override { return fft2_name(out_of_place_); }
    std::string detail() const override { return plan_ ? plan_->describe() : ""; }
    bool supports(size_t n, int batch, std::string* why) const override {
        if (n < (size_t{1} << 16) || n > (size_t{1} << 24) || (n & (n - 1)) || batch < 1) {
            if (why) *why = "fft2 requires power-of-two N in [2^16, 2^24] and batch >= 1";
            return false;
        }
        // Plan owns one full workspace; the adapter owns one or two data
        // buffers. The two twiddle and two cross tables have at most 4096 entries each.
        const size_t buffers = out_of_place_ ? 3 : 2;
        const size_t table_budget = 4 * 4096 * sizeof(cuDoubleComplex);
        if (size_t(batch) > (std::numeric_limits<size_t>::max() - table_budget) /
                            sizeof(cuDoubleComplex) / n / buffers) {
            if (why) *why = "fft2 buffer byte count overflows size_t";
            return false;
        }
        const size_t required = n * size_t(batch) * sizeof(cuDoubleComplex) * buffers + table_budget;
        size_t available = 0, total = 0;
        T1_CUDA(cudaMemGetInfo(&available, &total));
        if (required > available) {
            if (why) *why = "fft2 buffers/workspace/tables need up to " + std::to_string(required) +
                            " bytes; free device bytes=" + std::to_string(available);
            return false;
        }
        return true;
    }
    void plan(size_t n, int batch) override {
        if (plan_) throw std::runtime_error("fft2 plan already exists");
        std::string reason;
        if (!supports(n, batch, &reason)) throw std::runtime_error(reason);
        data_.allocate(elements(n, batch));
        if (out_of_place_) output_.allocate(elements(n, batch));
        plan_ = std::make_unique<fft2::Plan>(n, batch);
    }
    cuDoubleComplex* buffer() override { return data_.get(); }
    cuDoubleComplex* output() override { return out_of_place_ ? output_.get() : data_.get(); }
    void execute(cudaStream_t stream) override {
        plan_->execute(data_.get(), output(), stream);
    }
    void destroy() override {
        plan_.reset();
        output_.reset();
        data_.reset();
    }
};
std::unique_ptr<FftBackend> make_fft2(bool out_of_place) {
    return std::make_unique<Fft2>(out_of_place);
}
} // namespace measure
