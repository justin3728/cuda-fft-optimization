# Default: build the fft2 test. Measurement targets (tools, bench) live in bench/Makefile.inc.
CUDA_ARCH ?= sm_80

.PHONY: default all help
default: all
all:
	$(MAKE) -C fft2 CUDA_ARCH=$(CUDA_ARCH)

help:
	@echo "make [CUDA_ARCH=sm_80]                      Build fft2/fft2_test"
	@echo "make tools TAG=<tag> [CUDA_ARCH=sm_80]      Build results/<tag>/build/bwtest"
	@echo "make bench TAG=<tag> [WITH_FFTW=1]          Build results/<tag>/build/fft_bench"
	@echo "make -B ...                                 Force rebuild after arch changes"

include bench/Makefile.inc
