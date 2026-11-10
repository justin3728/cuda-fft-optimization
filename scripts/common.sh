#!/usr/bin/env bash
# Shared argument handling; scripts are run from any working directory.
set -euo pipefail
T1_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$T1_ROOT"
tag='' quick=0 dry_run=0 skip_ncu=0 verify_fftw=0
log2='' batch_modes='' impls='legacy,cufft,vkfft' trials='' iters=20
profile_log2='' profile_batch_modes='b1,t25'
PYTHON=${PYTHON:-python3}
NCU=${NCU:-ncu}

t1_parse() {
    while (($#)); do
        case $1 in
            --tag|--log2|--batch-modes|--impls|--trials|--iters|--profile-log2|--profile-batch-modes)
                (($# >= 2)) || { echo "Missing value for $1" >&2; exit 2; }
                case $1 in
                    --tag) tag=$2;; --log2) log2=$2;; --batch-modes) batch_modes=$2;;
                    --impls) impls=$2;; --trials) trials=$2;; --iters) iters=$2;;
                    --profile-log2) profile_log2=$2;; --profile-batch-modes) profile_batch_modes=$2;;
                esac
                shift 2;;
            --quick) quick=1; shift;;
            --dry-run) dry_run=1; shift;;
            --skip-ncu) skip_ncu=1; shift;;
            --verify-fftw) verify_fftw=1; shift;;
            --help|-h)
                echo "Usage: $0 --tag NEW_TAG [--quick] [--skip-ncu] [--dry-run]"
                echo '  [--log2 16,...,24] [--batch-modes b1,b8,t25] [--impls legacy,cufft,vkfft]'
                echo '  [--trials 15] [--iters 20] [--verify-fftw]'
                echo '  [--profile-log2 16,20,22,24] [--profile-batch-modes b1,t25]'
                exit 0;;
            *) echo "Unknown argument: $1" >&2; exit 2;;
        esac
    done
    [[ $tag =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || { echo 'A safe --tag is required (letters/digits/_,.,-; start with letter/digit)' >&2; exit 2; }
    if ((quick)); then
        log2=${log2:-16,20,24}; batch_modes=${batch_modes:-b1}; trials=${trials:-3}
        profile_log2=${profile_log2:-20}; profile_batch_modes='b1'
    else
        log2=${log2:-16,17,18,19,20,21,22,23,24}; batch_modes=${batch_modes:-b1,b8,t25}; trials=${trials:-15}
        profile_log2=${profile_log2:-16,20,22,24}
    fi
    [[ $log2 =~ ^[0-9]+(,[0-9]+)*$ && $profile_log2 =~ ^[0-9]+(,[0-9]+)*$ ]] || { echo 'Invalid exponent list' >&2; exit 2; }
    [[ $batch_modes =~ ^[bt][0-9]+(,[bt][0-9]+)*$ && $profile_batch_modes =~ ^[bt][0-9]+(,[bt][0-9]+)*$ ]] || { echo 'Invalid batch modes' >&2; exit 2; }
    [[ $impls =~ ^(legacy|cufft|vkfft)(,(legacy|cufft|vkfft))*$ ]] || { echo 'Invalid implementation list' >&2; exit 2; }
    [[ $trials =~ ^[1-9][0-9]*$ && $iters =~ ^[1-9][0-9]*$ ]] || { echo 'Trials/iters must be positive integers' >&2; exit 2; }
    out="results/$tag"
    # Public globals used by the scripts that source this file.
    # shellcheck disable=SC2034
    bench_bin="$out/build/fft_bench"
    # shellcheck disable=SC2034
    bw_bin="$out/build/bwtest"
    sweep_args=(--tag "$tag" --log2 "$log2" --batch-modes "$batch_modes" --trials "$trials" --iters "$iters")
    forward_args=("${sweep_args[@]}" --impls "$impls" --profile-log2 "$profile_log2" --profile-batch-modes "$profile_batch_modes")
    ((quick == 0)) || forward_args+=(--quick)
    ((verify_fftw == 0)) || forward_args+=(--verify-fftw)
    ((skip_ncu == 0)) || forward_args+=(--skip-ncu)
}

t1_print() { printf '+ '; printf '%q ' "$@"; printf '\n'; }
t1_run() { t1_print "$@"; if ((dry_run == 0)); then "$@"; fi; }
t1_require_new() { [[ ! -e $1 ]] || { echo "Refusing to overwrite $1; choose a new tag" >&2; exit 2; }; }
t1_batch() {
    local n=$1 mode=$2 exponent value
    [[ $mode =~ ^([bt])([0-9]+)$ ]] || return 2
    exponent=${BASH_REMATCH[2]}
    ((${#exponent} <= 10)) || { echo 'Batch mode value too large' >&2; return 2; }
    value=$((10#$exponent))
    if [[ ${BASH_REMATCH[1]} == b ]]; then
        ((value > 0 && value <= 2147483647)) || return 2
        printf '%s' "$value"
    else
        ((value > 0 && value <= 30 && (1 << value) >= n)) || { echo "Invalid fixed-total mode $mode at N=$n" >&2; return 2; }
        printf '%s' "$(((1 << value) / n))"
    fi
}
t1_exponents() {
    local list=$1 value
    local -a values
    IFS=',' read -r -a values <<< "$list"
    for value in "${values[@]}"; do
        ((${#value} <= 2)) || { echo 'Exponent too large' >&2; return 2; }
        value=$((10#$value))
        ((value >= 1 && value <= 30)) || { echo 'Exponents must be 1..30' >&2; return 2; }
        printf '%s\n' "$value"
    done
}
