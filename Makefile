APP_NAME = benchmark
OBJS = fft_cuda.o

# -------------------------------------------------
# A100: make CUDA_ARCH=sm_80
# Legacy default is unchanged: sm_61. Rebuild with -B when changing architecture.
CUDA_ARCH ?= sm_61

# -------------------------------------------------
# Host compiler settings used by nvcc for benchmark.cpp
# -------------------------------------------------
NVCC_LINKFLAGS = -I. \
                 -std=c++11 \
                 -Xcompiler=-Wall \
                 -Xcompiler=-fopenmp \
                 -Xcompiler=-Wno-unknown-pragmas
# FFTW pthread backend (not fftw3_omp); FFTW must include thread support.
LDLIBS = -lcufft -lfftw3_threads -lfftw3 -lpthread -lm

# -------------------------------------------------
# NVCC settings
# -------------------------------------------------
NVCC = nvcc
NVCCFLAGS = -O3 -m64 \
            -arch=$(CUDA_ARCH) \
            --compiler-options '-fPIC' \
            --ptxas-options=-v

# -------------------------------------------------
# Build rules
# -------------------------------------------------
.PHONY: default all clean help
default: $(APP_NAME)
all: $(APP_NAME)

# Compile CUDA source
fft_cuda.o: fft_cuda.cu fft_cuda.h
	$(NVCC) $< $(NVCCFLAGS) -c -o $@

# Build benchmark executable
$(APP_NAME): benchmark.cpp $(OBJS)
	$(NVCC) benchmark.cpp $(OBJS) $(NVCC_LINKFLAGS) $(LDLIBS) -o $(APP_NAME)

# Clean
clean:
	rm -f *.o $(APP_NAME) profile_stages

# Optional diagnostic executable; normal benchmark does not depend on it.
# Includes fft_cuda.cu directly: do not also link fft_cuda.o.
profile_stages: profile_stages.cu fft_cuda.cu fft_cuda.h
	$(NVCC) profile_stages.cu $(NVCCFLAGS) -std=c++11 --resource-usage -o $@

help:
	@echo "make CUDA_ARCH=sm_80                 Build normal benchmark for A100"
	@echo "./benchmark --fftw-threads 8         Compare single/multi-thread FFTW and CUDA"
	@echo "make profile_stages CUDA_ARCH=sm_80  Build optional stage profiler"
	@echo "./profile_stages                    Run N=2^20 diagnostic"
	@echo "make -B CUDA_ARCH=sm_80              Force rebuild after arch changes"
	@echo "make clean                          Remove generated executables/object"

# Optional measurement tools; does not alter the legacy default target.
include bench/Makefile.inc
