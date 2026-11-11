#include "backend.hpp"
#include <cuda.h>
#include <nvrtc.h>

#ifndef T1_VKFFT_COMMIT
#define T1_VKFFT_COMMIT "unknown"
#endif

namespace {
struct Launch {
    CUfunction function;
    unsigned int gx, gy, gz, bx, by, bz, shared;
};
std::vector<Launch>* capture = nullptr;
// Only our include's launch calls are wrapped. This records actual driver
// dispatches during export, including any split grids, without editing VkFFT.
CUresult CUDAAPI record_launch(CUfunction f, unsigned int gx, unsigned int gy, unsigned int gz,
                              unsigned int bx, unsigned int by, unsigned int bz, unsigned int shared,
                              CUstream stream, void** args, void** extra) {
    if (capture) capture->push_back({f, gx, gy, gz, bx, by, bz, shared});
    return cuLaunchKernel(f, gx, gy, gz, bx, by, bz, shared, stream, args, extra);
}
}
#define VKFFT_BACKEND 1
#define cuLaunchKernel record_launch
#include <vkFFT.h>
#undef cuLaunchKernel

namespace measure {
inline void vk_check(VkFFTResult result, const char* call) {
    if (result != VKFFT_SUCCESS)
        throw std::runtime_error(std::string(call) + ": " + getVkFFTErrorString(result));
}
class Vkfft final : public FftBackend {
    VkFFTApplication app_{};
    DeviceBuffer<cuDoubleComplex> data_;
    CUdevice device_ = 0;
    cudaStream_t stream_ = nullptr;
    void* pointer_ = nullptr;
    pfUINT bytes_ = 0;
    size_t n_ = 0;
    int batch_ = 0;
    bool ready_ = false, keep_code_;
public:
    explicit Vkfft(bool keep_code) : keep_code_(keep_code) {}
    ~Vkfft() override { if (ready_) deleteVkFFT(&app_); }
    std::string name() const override { return "vkfft"; }
    bool supports(size_t n, int batch, std::string* why) const override { return cufft_dimensions(n, batch, why); }
    void plan(size_t n, int batch) override {
        std::string reason;
        if (!supports(n, batch, &reason)) throw std::runtime_error(reason);
        data_.allocate(elements(n, batch));
        int ordinal = 0;
        T1_CUDA(cudaGetDevice(&ordinal));
        if (cuDeviceGet(&device_, ordinal) != CUDA_SUCCESS) throw std::runtime_error("cuDeviceGet failed");
        n_ = n; batch_ = batch;
        pointer_ = data_.get(); bytes_ = pfUINT(elements(n, batch) * sizeof(cuDoubleComplex));
        VkFFTConfiguration config{};
        config.FFTdim = 1; config.size[0] = pfUINT(n);
        config.device = &device_; config.stream = &stream_; config.num_streams = 1;
        config.buffer = &pointer_; config.bufferSize = &bytes_;
        config.doublePrecision = 1; config.numberBatches = pfUINT(batch);
        config.makeForwardPlanOnly = 1; config.keepShaderCode = keep_code_ ? 1 : 0;
        // VkFFTAppend inverse=-1 selects exp(-2*pi*i*k/N), matching CUFFT_FORWARD.
        // No normalization is requested. GPU correctness compares both libraries.
        vk_check(initializeVkFFT(&app_, config), "initializeVkFFT");
        ready_ = true;
        // Initialization may enqueue work on stream 0. Measurement uses a
        // nonblocking stream, so explicitly complete setup before handing the
        // initialized plan to correctness, warmup, profiling or export paths.
        T1_CUDA(cudaDeviceSynchronize());
    }
    cuDoubleComplex* buffer() override { return data_.get(); }
    void execute(cudaStream_t stream) override {
        if (stream != stream_) stream_ = stream;
        VkFFTLaunchParams launch{};
        vk_check(VkFFTAppend(&app_, -1, &launch), "VkFFTAppend(forward)");
    }
    void destroy() override {
        if (ready_) { deleteVkFFT(&app_); ready_ = false; }
        data_.reset();
    }
    void export_kernels(const std::filesystem::path& directory) override {
        if (!keep_code_ || !ready_) throw std::runtime_error("export requires a keepShaderCode plan");
        Stream stream;
        fill_for_export(stream.value);
        std::vector<Launch> launches;
        capture = &launches;
        // keepShaderCode retained code0 at initialization. Disable only its
        // stdout printing during this execution; restore before deleteVkFFT.
        app_.configuration.keepShaderCode = 0;
        try { execute(stream.value); T1_CUDA(cudaStreamSynchronize(stream.value)); }
        catch (...) { capture = nullptr; app_.configuration.keepShaderCode = 1; throw; }
        capture = nullptr; app_.configuration.keepShaderCode = 1;
        if (launches.empty()) throw std::runtime_error("VkFFT export captured zero driver launches");
        auto manifest = new_output(directory / "manifest.json");
        manifest << "{\n  \"vkfft_version\": " << VkFFTGetVersion()
                 << ",\n  \"vkfft_commit\": " << json(T1_VKFFT_COMMIT)
                 << ",\n  \"config\": {\"FFTdim\":1,\"size\":[" << n_
                 << "],\"numberBatches\":" << batch_
                 << ",\"bufferSize_bytes\":" << bytes_ << ",\"device_ordinal\":" << device_
                 << ",\"doublePrecision\":1,\"num_streams\":1,\"makeForwardPlanOnly\":1,\"keepShaderCode\":1,\"normalize\":0,\"inverse\":-1},\n"
                 << "  \"kernel_count\": " << launches.size() << ",\n  \"kernels\": [\n";
        for (size_t i = 0; i < launches.size(); ++i) {
            const auto& item = launches[i];
            const VkFFTAxis* found = nullptr;
            for (pfUINT axis = 0; axis < app_.configuration.FFTdim; ++axis)
                for (pfUINT k = 0; k < app_.localFFTPlan->numAxisUploads[axis]; ++k)
                    if (app_.localFFTPlan->axes[axis][k].VkFFTKernel == item.function)
                        found = &app_.localFFTPlan->axes[axis][k];
            if (!found || !found->specializationConstants.code0)
                throw std::runtime_error("driver launch has no retained VkFFT source; pinned API changed");
            const std::string file = "kernel_" + std::to_string(i) + ".cu";
            auto source = new_output(directory / file);
            source << found->specializationConstants.code0;
            int static_shared = 0;
            const bool have_static = cuFuncGetAttribute(&static_shared, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES,
                                                        item.function) == CUDA_SUCCESS;
            manifest << "    {\"file\":" << json(file) << ",\"name\":" << json(found->VkFFTFunctionName)
                     << ",\"grid\":[" << item.gx << ',' << item.gy << ',' << item.gz
                     << "],\"block\":[" << item.bx << ',' << item.by << ',' << item.bz
                     << "],\"dynamic_shared_bytes\":" << item.shared << ",\"static_shared_bytes\":";
            if (have_static) manifest << static_shared; else manifest << "null";
            manifest << '}' << (i + 1 == launches.size() ? "\n" : ",\n");
        }
        manifest << "  ]\n}\n";
    }
private:
    void fill_for_export(cudaStream_t stream) {
        T1_CUDA(cudaMemsetAsync(data_.get(), 0, size_t(bytes_), stream));
    }
};
std::unique_ptr<FftBackend> make_vkfft(bool keep_code) { return std::make_unique<Vkfft>(keep_code); }
} // namespace measure
