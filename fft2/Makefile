NVCC ?= nvcc
PYTHON ?= python3
CUDA_ARCH ?= sm_80

# CUDA 13 supports all-warnings; old nvcc versions may override this variable.
NVCC_WARNING_FLAGS ?= -Werror=all-warnings
NVCCFLAGS ?= -O3 -std=c++17
HOST_WARNING_FLAGS := -Xcompiler=-Wall,-Wextra,-Werror
BUILD_DIR := build/$(CUDA_ARCH)
OBJECTS := $(BUILD_DIR)/fft2.o $(BUILD_DIR)/fft2_test.o

.PHONY: all clean test-cpu test-cpu-slow test-tile-policy FORCE
all: fft2_test

# Relink even when switching back to an already-built architecture. Otherwise
# a newer sm_89 executable could incorrectly satisfy a subsequent sm_80 build.
fft2_test: $(OBJECTS) FORCE
	$(NVCC) $(NVCCFLAGS) -arch=$(CUDA_ARCH) $(NVCC_WARNING_FLAGS) $(HOST_WARNING_FLAGS) $(OBJECTS) -lcufft -o $@

$(BUILD_DIR)/fft2.o: fft2.cu fft2.h detail/tile_policy.h
	@mkdir -p $(BUILD_DIR)
	$(NVCC) $(NVCCFLAGS) -arch=$(CUDA_ARCH) $(NVCC_WARNING_FLAGS) $(HOST_WARNING_FLAGS) -I. -c $< -o $@

$(BUILD_DIR)/fft2_test.o: tests/fft2_test.cu fft2.h
	@mkdir -p $(BUILD_DIR)
	$(NVCC) $(NVCCFLAGS) -arch=$(CUDA_ARCH) $(NVCC_WARNING_FLAGS) $(HOST_WARNING_FLAGS) -I. -c $< -o $@

build/cpu/tile_policy_test: tests/tile_policy_test.cpp detail/tile_policy.h
	@mkdir -p build/cpu
	$(CXX) -std=c++17 -Wall -Wextra -Werror -I. $< -o $@

test-tile-policy: build/cpu/tile_policy_test
	./build/cpu/tile_policy_test

test-cpu: test-tile-policy
	$(PYTHON) -m pytest reference -q

test-cpu-slow: test-tile-policy
	$(PYTHON) -m pytest reference -q --run-slow

clean:
	rm -rf build fft2_test
