#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
args=("${sweep_args[@]}" --impls "$impls" "${fft2_args[@]}")
((verify_fftw == 0)) || args+=(--verify-fftw)
t1_run "$bench_bin" "${args[@]}"
