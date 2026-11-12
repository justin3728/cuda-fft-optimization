#pragma once
#if __has_include(<nvtx3/nvToolsExt.h>)
#include <nvtx3/nvToolsExt.h>
#else
#error "NVTX3 headers required: install NVIDIA NVTX3 headers and add their include directory to nvcc's search path"
#endif
#include <string>
namespace measure {
struct NvtxRange {
    explicit NvtxRange(const std::string& name) { nvtxRangePushA(name.c_str()); }
    ~NvtxRange() { nvtxRangePop(); }
    NvtxRange(const NvtxRange&) = delete;
    NvtxRange& operator=(const NvtxRange&) = delete;
};
}
