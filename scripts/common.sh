#!/usr/bin/env bash
# Shared argument handling; scripts are run from any working directory.
set -euo pipefail
T1_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$T1_ROOT"
tag='' quick=0 dry_run=0 skip_ncu=0 verify_fftw=0 skip_copy_profiles=0
log2='' batch_modes='' impls='legacy,cufft,vkfft,fft2' trials='' iters=20
fft2_n1=0 fft2_tile_cols=0 fft2_tile_rows=0 fft2_out_of_place=0
fft2_index_mode=0 fft2_smem_padding=0 fft2_tile_policy=0 fft2_twiddle_mode=0 fft2_cross_mode=0 fft2_radix_mode=0
fft2_io_mode=0
profile_log2='' profile_batch_modes='b1,t25'
ncu_max_kernels=50 ncu_library_max_kernels=12
PYTHON=${PYTHON:-python3}
NCU=${NCU:-ncu}

t1_parse() {
    while (($#)); do
        case $1 in
            --tag|--log2|--batch-modes|--impl|--impls|--trials|--iters|--profile-log2|--profile-batch-modes|--ncu-max-kernels|--ncu-library-max-kernels|--fft2-n1|--fft2-tile-cols|--fft2-tile-rows|--fft2-index-mode|--fft2-smem-padding|--fft2-tile-policy|--fft2-twiddle-mode|--fft2-cross-mode|--fft2-io-mode|--fft2-radix-mode)
                (($# >= 2)) || { echo "Missing value for $1" >&2; exit 2; }
                case $1 in
                    --tag) tag=$2;; --log2) log2=$2;; --batch-modes) batch_modes=$2;;
                    --impl|--impls) impls=$2;; --trials) trials=$2;; --iters) iters=$2;;
                    --fft2-n1) fft2_n1=$2;; --fft2-tile-cols) fft2_tile_cols=$2;; --fft2-tile-rows) fft2_tile_rows=$2;;
                    --fft2-index-mode) fft2_index_mode=$2;; --fft2-smem-padding) fft2_smem_padding=$2;;
                    --fft2-tile-policy) fft2_tile_policy=$2;; --fft2-radix-mode) fft2_radix_mode=$2;; --fft2-cross-mode) fft2_cross_mode=$2;; --fft2-twiddle-mode) fft2_twiddle_mode=$2;;
                    --fft2-io-mode) fft2_io_mode=$2;;
                    --profile-log2) profile_log2=$2;; --profile-batch-modes) profile_batch_modes=$2;;
                    --ncu-max-kernels) ncu_max_kernels=$2;; --ncu-library-max-kernels) ncu_library_max_kernels=$2;;
                esac
                shift 2;;
            --quick) quick=1; shift;;
            --dry-run) dry_run=1; shift;;
            --skip-ncu) skip_ncu=1; shift;;
            --skip-copy-profiles) skip_copy_profiles=1; shift;;
            --verify-fftw) verify_fftw=1; shift;;
            --fft2-out-of-place) fft2_out_of_place=1; shift;;
            --help|-h)
                echo "Usage: $0 --tag NEW_TAG [--quick] [--skip-ncu] [--dry-run]"
                echo '  [--log2 16,...,24] [--batch-modes b1,b8,t25] [--impls legacy,cufft,vkfft,fft2]'
                echo '  [--fft2-n1 0] [--fft2-tile-cols 0] [--fft2-tile-rows 0] [--fft2-out-of-place]'
                echo '  [--fft2-index-mode 0|1] [--fft2-smem-padding 0|1|2] (default: 0)'
                echo '  [--fft2-tile-policy 0|1] [--fft2-radix-mode -1|0|1|2] (default: 0; -1 = auto radix)'
                echo '  [--fft2-twiddle-mode 0|1] [--fft2-cross-mode 0|1] (default: 0)'
                echo '  [--fft2-io-mode 0|1|2] (default: 0; nonzero requires register radix)'
                echo '  [--trials 15] [--iters 20] [--verify-fftw]'
                echo '  [--profile-log2 16,20,22,24] [--profile-batch-modes b1,t25]'
                echo '  [--ncu-max-kernels 50] [--ncu-library-max-kernels 12]'
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
    [[ $impls =~ ^(legacy|cufft|vkfft|fft2)(,(legacy|cufft|vkfft|fft2))*$ ]] || { echo 'Invalid implementation list' >&2; exit 2; }
    local value
    for value in "$fft2_n1" "$fft2_tile_cols" "$fft2_tile_rows" "$fft2_index_mode" "$fft2_smem_padding" "$fft2_tile_policy" "$fft2_twiddle_mode" "$fft2_cross_mode" "$fft2_io_mode"; do
        if ! [[ $value =~ ^[0-9]+$ ]] || ((${#value} > 10)) || ((10#$value > 2147483647)); then
            echo 'fft2 options must be nonnegative integers <= INT_MAX (0 = auto)' >&2; exit 2;
        fi
    done
    fft2_n1=$((10#$fft2_n1)); fft2_tile_cols=$((10#$fft2_tile_cols)); fft2_tile_rows=$((10#$fft2_tile_rows))
    fft2_index_mode=$((10#$fft2_index_mode)); fft2_smem_padding=$((10#$fft2_smem_padding))
    fft2_tile_policy=$((10#$fft2_tile_policy))
    if [[ $fft2_radix_mode != -1 ]]; then
        [[ $fft2_radix_mode =~ ^[0-9]+$ && ${#fft2_radix_mode} -le 10 ]] || {
            echo '--fft2-radix-mode must be -1, 0, 1 or 2' >&2; exit 2;
        }
        fft2_radix_mode=$((10#$fft2_radix_mode))
    fi
    ((fft2_tile_policy <= 1)) || { echo '--fft2-tile-policy must be 0 or 1' >&2; exit 2; }
    fft2_twiddle_mode=$((10#$fft2_twiddle_mode))
    ((fft2_twiddle_mode <= 1)) || { echo '--fft2-twiddle-mode must be 0 or 1' >&2; exit 2; }
    fft2_cross_mode=$((10#$fft2_cross_mode))
    ((fft2_cross_mode <= 1)) || { echo '--fft2-cross-mode must be 0 or 1' >&2; exit 2; }
    ((fft2_radix_mode <= 2)) || { echo '--fft2-radix-mode must be -1, 0, 1 or 2' >&2; exit 2; }
    fft2_io_mode=$((10#$fft2_io_mode))
    ((fft2_io_mode <= 2 && (fft2_io_mode == 0 || fft2_radix_mode != 0))) || {
        echo '--fft2-io-mode must be 0, 1 or 2; nonzero requires register radix' >&2; exit 2;
    }
    ((fft2_index_mode <= 1)) || { echo '--fft2-index-mode must be 0 or 1' >&2; exit 2; }
    ((fft2_smem_padding <= 2)) || { echo '--fft2-smem-padding must be 0, 1 or 2' >&2; exit 2; }
    [[ $trials =~ ^[1-9][0-9]*$ && $iters =~ ^[1-9][0-9]*$ ]] || { echo 'Trials/iters must be positive integers' >&2; exit 2; }
    [[ $ncu_max_kernels =~ ^[1-9][0-9]*$ && $ncu_library_max_kernels =~ ^[1-9][0-9]*$ ]] || { echo 'ncu capture limits must be positive integers' >&2; exit 2; }
    ((${#ncu_max_kernels} <= 9 && ${#ncu_library_max_kernels} <= 9)) || { echo 'ncu capture limits are too large' >&2; exit 2; }
    out="results/$tag"
    # Public globals used by the scripts that source this file.
    # shellcheck disable=SC2034
    bench_bin=${FFT_BENCH:-"$out/build/fft_bench"}
    # shellcheck disable=SC2034
    bw_bin=${BWTEST:-"$out/build/bwtest"}
    sweep_args=(--tag "$tag" --log2 "$log2" --batch-modes "$batch_modes" --trials "$trials" --iters "$iters")
    fft2_args=(--fft2-n1 "$fft2_n1" --fft2-tile-cols "$fft2_tile_cols" --fft2-tile-rows "$fft2_tile_rows"
               --fft2-index-mode "$fft2_index_mode" --fft2-smem-padding "$fft2_smem_padding"
               --fft2-tile-policy "$fft2_tile_policy" --fft2-twiddle-mode "$fft2_twiddle_mode" --fft2-cross-mode "$fft2_cross_mode" --fft2-io-mode "$fft2_io_mode" --fft2-radix-mode "$fft2_radix_mode")
    ((fft2_out_of_place == 0)) || fft2_args+=(--fft2-out-of-place)
    forward_args=("${sweep_args[@]}" --impls "$impls" --profile-log2 "$profile_log2" --profile-batch-modes "$profile_batch_modes"
                  --ncu-max-kernels "$ncu_max_kernels" --ncu-library-max-kernels "$ncu_library_max_kernels" "${fft2_args[@]}")
    ((quick == 0)) || forward_args+=(--quick)
    ((verify_fftw == 0)) || forward_args+=(--verify-fftw)
    ((skip_ncu == 0)) || forward_args+=(--skip-ncu)
    ((skip_copy_profiles == 0)) || forward_args+=(--skip-copy-profiles)
}

t1_print() { printf '+ '; printf '%q ' "$@"; printf '\n'; }
t1_run() { t1_print "$@"; if ((dry_run == 0)); then "$@"; fi; }
t1_require_new() { [[ ! -e $1 ]] || { echo "Refusing to overwrite $1; choose a new tag" >&2; exit 2; }; }
t1_fft2_name() {
    printf 'fft2[n1=%s,c=%s,r=%s' "$fft2_n1" "$fft2_tile_cols" "$fft2_tile_rows"
    ((fft2_index_mode == 0)) || printf ',im=%s' "$fft2_index_mode"
    ((fft2_smem_padding == 0)) || printf ',pad=%s' "$fft2_smem_padding"
    ((fft2_tile_policy == 0)) || printf ',tp=%s' "$fft2_tile_policy"
    if ((fft2_radix_mode == -1)); then printf ',rx=auto'
    elif ((fft2_radix_mode != 0)); then printf ',rx=%s' "$fft2_radix_mode"; fi
    ((fft2_twiddle_mode == 0)) || printf ',tw=%s' "$fft2_twiddle_mode"
    ((fft2_cross_mode == 0)) || printf ',cx=%s' "$fft2_cross_mode"
    ((fft2_io_mode == 0)) || printf ',io=%s' "$fft2_io_mode"
    ((fft2_out_of_place == 0)) || printf ',oop=1'
    printf ']'
}
t1_nvtx_filter() {
    local name=$1 char i
    for ((i=0; i<${#name}; ++i)); do
        char=${name:i:1}
        case $char in
            '['|']'|','|'/'|'@'|'*'|'+') printf '\\%s' "$char";;
            *) printf '%s' "$char";;
        esac
    done
    printf '/'
}
t1_csv_row() {
    local separator='' value
    for value in "$@"; do
        value=${value//\"/\"\"}
        printf '%s"%s"' "$separator" "$value"
        separator=,
    done
    printf '\n'
}
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
