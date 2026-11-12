#!/usr/bin/env bash
# Generic fft2 L4 gate: gate_fft2.sh BRANCH. Builds sm_89+sm_80 (zero warnings), ptxas regs/spills,
# CPU + pytest, fft2_test --variants. Writes /content/gate_done with the exit code.
# Run detached on a Colab runtime (see CLAUDE.md "No idle GPU time" checklist).
set -uo pipefail
BRANCH=${1:?usage: gate_fft2.sh BRANCH}
export PATH=/usr/local/cuda/bin:$PATH
R=https://github.com/justin3728/cuda-fft-optimization.git
W=/content/gate; rm -rf "$W"; mkdir -p "$W"; cd "$W" || exit 1
nvidia-smi --query-gpu=name --format=csv,noheader
fail=0
git clone -q -b "$BRANCH" "$R" src && cd src && git log --oneline -1
for arch in sm_89 sm_80; do
  if make -C fft2 -B CUDA_ARCH=$arch > build_$arch.log 2>&1 && ! grep -qi "warning:" build_$arch.log; then echo "BUILD_$arch PASS"; else echo "BUILD_$arch FAIL"; tail -30 build_$arch.log; fail=1; fi
done
(cd fft2 && nvcc -O3 -std=c++17 -arch=sm_80 -Xptxas -v -I. -c fft2.cu -o /tmp/ptx.o 2>&1 | grep -E "Compiling entry|registers|spill" > ../ptxas_sm80.txt)
echo "PTXAS: $(grep -c registers ptxas_sm80.txt) kernels; max regs $(grep -o 'Used [0-9]* registers' ptxas_sm80.txt | awk '{print $2}' | sort -n | tail -1); nonzero spills: $(grep -E 'spill' ptxas_sm80.txt | grep -vc ' 0 bytes spill stores, 0 bytes spill loads')"
make -C fft2 -B CUDA_ARCH=sm_89 > /dev/null 2>&1
if make -C fft2 test-cpu CUDA_ARCH=sm_89 > cpu.log 2>&1; then echo "CPU PASS"; else echo "CPU FAIL"; tail -20 cpu.log; fail=1; fi
pip -q install numpy pytest >/dev/null 2>&1; if python3 -m pytest -q fft2/reference > pytest.log 2>&1; then echo "PYTEST PASS"; else echo "PYTEST FAIL"; tail -15 pytest.log; fail=1; fi
s=$(date +%s)
if timeout 1500 fft2/fft2_test --variants > variants.log 2>&1; then echo "GPU PASS"; else echo "GPU FAIL rc=$?"; grep -E "FAIL" variants.log | head -10; fail=1; fi
echo "VARIANTS_SECONDS $(( $(date +%s) - s ))"
grep -E "^SUMMARY" variants.log
grep -E "VARIANT_SUMMARY.*(twiddle_mode=1|cross_mode=1)" variants.log | head -8
grep -E "twiddle_mode=1|cross_mode=1" variants.log | grep -oE "rel_l2=[0-9.e+-]+" | sort -t= -k2 -g | tail -1 | sed 's/^/max new-mode /'
echo "GATE_EXIT $fail"
echo $fail > /content/gate_done
