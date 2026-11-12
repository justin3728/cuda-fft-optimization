#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
failed=0
declare -A exported_pairs=()
if ((quick)); then profile_log2=$log2; profile_batch_modes=$batch_modes; fi
IFS=',' read -r -a modes <<< "$profile_batch_modes"
exponents=$(t1_exponents "$profile_log2")
while read -r exponent; do
    n=$((1 << exponent))
    for mode in "${modes[@]}"; do
        batch=$(t1_batch "$n" "$mode")
        pair="$n:$batch"
        if [[ -n ${exported_pairs[$pair]+present} ]]; then
            echo "Reusing VkFFT export: N=$n batch=$batch (batch mode $mode)"
            continue
        fi
        exported_pairs[$pair]=1
        if ! t1_run "$bench_bin" --tag "$tag" --export-vkfft --impls vkfft --n "$n" --batch "$batch" --batch-modes "$mode"; then
            echo "VkFFT export failed: N=$n batch=$batch" >&2; failed=1
        fi
    done
done <<< "$exponents"
exit "$failed"
