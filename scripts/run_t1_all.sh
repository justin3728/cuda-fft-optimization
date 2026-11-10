#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
if ((dry_run == 0)); then
    t1_require_new "$out"
    mkdir -p "$out/logs"
fi
stages=() statuses=() elapsed=()
failed=0
stage() {
    local name=$1 start=$SECONDS code=0
    shift
    stages+=("$name")
    echo "=== $name -> $out/logs/$name.log ==="
    if ((dry_run)); then
        "$@"; statuses+=(DRY-RUN); elapsed+=(0); return
    fi
    # Explicitly test each stage so independent later stages always run.
    if "$@" > "$out/logs/$name.log" 2>&1; then code=0; else code=$?; fi
    cat "$out/logs/$name.log"
    if ((code)); then statuses+=("FAIL($code)"); failed=1; else statuses+=(OK); fi
    elapsed+=("$((SECONDS - start))")
    printf '%s elapsed: %s s\n' "$name" "${elapsed[-1]}"
}
# Passed by name to stage(), which invokes its arguments.
# shellcheck disable=SC2329
build() {
    t1_run git submodule update --init third_party/VkFFT || return
    t1_run make -B tools bench "CUDA_ARCH=${CUDA_ARCH:-sm_80}" "TAG=$tag" "WITH_FFTW=$verify_fftw"
}
# Passed by name to stage(), which invokes its arguments.
# shellcheck disable=SC2329
script_stage() {
    local script=$1
    local -a args=("${forward_args[@]}")
    ((dry_run == 0)) || args+=(--dry-run)
    t1_print "scripts/$script" "${args[@]}"
    "scripts/$script" "${args[@]}"
}
stage build build
stage collect_env script_stage collect_env.sh
stage bandwidth script_stage run_bwtest.sh
stage sweep script_stage run_sweep.sh
stage vkfft_export script_stage export_vkfft_kernels.sh
if ((skip_ncu)); then stages+=(ncu); statuses+=(SKIPPED); elapsed+=(0)
else stage ncu script_stage run_ncu.sh; fi
stage analysis script_stage run_analysis.sh
printf '\n%-16s %-14s %s\n' STAGE STATUS SECONDS
for i in "${!stages[@]}"; do printf '%-16s %-14s %s\n' "${stages[i]}" "${statuses[i]}" "${elapsed[i]}"; done
if ((dry_run == 0)); then
    printf 'stage,status,elapsed_seconds\n' > "$out/stage_status.csv"
    for i in "${!stages[@]}"; do printf '%s,%s,%s\n' "${stages[i]}" "${statuses[i]}" "${elapsed[i]}" >> "$out/stage_status.csv"; done
    echo 'Files produced (build products excluded):'
    find "$out" -path "$out/build" -prune -o -type f -print
fi
echo 'Commands to stage run outputs (build products are ignored):'
t1_print git add -- "$out"
t1_print git add -f -- "$out/logs" "$out/sweep/config_logs"
exit "$failed"
