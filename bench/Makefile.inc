# Included after every legacy rule, so the original default target and its
# CUDA_ARCH=sm_61 default remain unchanged. New targets default to sm_80.
.PHONY: tools bench
T1_ARCH = $(if $(filter command line environment,$(origin CUDA_ARCH)),$(CUDA_ARCH),sm_80)
T1_OUT = results/$(TAG)/build
T1_NVCC ?= nvcc
T1_CUDA_HOME = $(if $(CUDA_HOME),$(CUDA_HOME),$(patsubst %/bin/,%,$(dir $(shell readlink -f "$$(command -v $(T1_NVCC))" 2>/dev/null))))
T1_VKFFT_SHA = $(shell git -C third_party/VkFFT rev-parse HEAD 2>/dev/null)
T1_FLAGS = -O3 -m64 -arch=$(T1_ARCH) -std=c++17 -I. -Xcompiler=-Wall,-Wextra
# -isystem keeps third-party diagnostics separate from warnings in our code.
T1_INCLUDES = --system-include=third_party/VkFFT/vkFFT
T1_DEFS = -DT1_VKFFT_COMMIT=\"$(T1_VKFFT_SHA)\"
# Only the link-time search path uses stubs; never put stubs on runtime rpath.
T1_DRIVER_DIR = $(firstword $(wildcard $(T1_CUDA_HOME)/lib64/stubs $(T1_CUDA_HOME)/targets/x86_64-linux/lib/stubs /usr/lib/x86_64-linux-gnu/stubs))
T1_LIBS = -lcufft -lnvrtc $(if $(T1_DRIVER_DIR),-L$(T1_DRIVER_DIR)) -lcuda -ldl
ifeq ($(WITH_FFTW),1)
T1_DEFS += -DT1_WITH_FFTW
T1_LIBS += -lfftw3
endif
T1_HEADERS = $(wildcard bench/common/*.cuh bench/common/*.hpp bench/backends/*.hpp)

tools: $(T1_OUT)/bwtest
bench: $(T1_OUT)/fft_bench

$(T1_OUT):
	@test -n "$(TAG)" || { echo 'New measurement targets require TAG=<new-results-tag>' >&2; exit 1; }
	@case '$(TAG)' in *[!a-zA-Z0-9_.-]*|.*|-*) echo 'Invalid TAG' >&2; exit 1;; esac
	mkdir -p $@

$(T1_OUT)/legacy.o: fft_cuda.cu fft_cuda.h | $(T1_OUT)
	$(T1_NVCC) -O3 -m64 -arch=$(T1_ARCH) -std=c++17 -I. -c $< -o $@

$(T1_OUT)/bwtest: tools/bwtest.cu $(T1_HEADERS) | $(T1_OUT)
	$(T1_NVCC) $(T1_FLAGS) $< -o $@ -ldl

$(T1_OUT)/fft_bench: bench/fft_bench.cu bench/backends/legacy.cu bench/backends/cufft.cu bench/backends/vkfft.cu $(T1_HEADERS) $(T1_OUT)/legacy.o | $(T1_OUT)
	@test -f third_party/VkFFT/vkFFT/vkFFT.h || { echo 'Run git submodule update --init third_party/VkFFT' >&2; exit 1; }
	$(T1_NVCC) $(T1_FLAGS) $(T1_INCLUDES) $(T1_DEFS) bench/fft_bench.cu bench/backends/legacy.cu bench/backends/cufft.cu bench/backends/vkfft.cu $(T1_OUT)/legacy.o -o $@ $(T1_LIBS)
