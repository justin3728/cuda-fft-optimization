#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
if ((dry_run)); then
    printf 'Environment commands -> %s/env.txt\n' "$out"
    t1_print date -Is
    t1_print uname -a
    t1_print nvidia-smi -q
    t1_print nvidia-smi -q -d SUPPORTED_CLOCKS
    t1_print nvcc --version
    t1_print "$NCU" --version
    t1_print "$bench_bin" --versions
    t1_print git -C third_party/VkFFT describe --tags --always
    t1_print git -C third_party/VkFFT rev-parse HEAD
    t1_print git rev-parse HEAD
    t1_print id
    exit 0
fi
mkdir -p "$out"
t1_require_new "$out/env.txt"
failed=0
record() {
    t1_print "$@"
    if ! "$@"; then echo 'NA: command failed or is unavailable'; failed=1; fi
    printf '\n'
}
record_optional() {
    t1_print "$@"
    if ! "$@"; then echo 'NA: optional environment query failed or is unavailable'; fi
    printf '\n'
}
{
    record date -Is
    record uname -a
    record nvidia-smi -q
    record nvidia-smi -q -d SUPPORTED_CLOCKS
    record nvcc --version
    record_optional "$NCU" --version
    if [[ -x $bench_bin ]]; then record "$bench_bin" --versions
    else echo 'cuFFT version: NA (build did not produce fft_bench)'; failed=1; fi
    record git -C third_party/VkFFT describe --tags --always
    record git -C third_party/VkFFT rev-parse HEAD
    record git rev-parse HEAD
    record id
    echo 'Clock lock probe: not attempted; ability to lock clocks is unverified.'
    echo 'Supported/current/application clocks are recorded above; no clocks, power limits or persistence settings changed.'
    echo 'All GPU performance/correctness results require execution on the target GPU.'
} > "$out/env.txt" 2>&1
cat "$out/env.txt"
exit "$failed"
