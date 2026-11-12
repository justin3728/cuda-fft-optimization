#!/usr/bin/env bash
# One invocation inside one GPU allocation: build/calibrate once, then run all variants.
set -euo pipefail
invocation_dir=$PWD
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
variants_file="$T1_ROOT/scripts/fft2_variants_default.txt" with_ncu=0
common_args=()
while (($#)); do
    case $1 in
        --variants)
            (($# >= 2)) || { echo 'Missing --variants file' >&2; exit 2; }
            variants_file=$2; shift 2;;
        --ncu) with_ncu=1; shift;;
        --impl|--impls|--fft2-n1|--fft2-tile-cols|--fft2-tile-rows|--fft2-index-mode|--fft2-smem-padding|--skip-copy-profiles)
            echo 'Choose variant tuning in FILE; the runner always includes all three baselines.' >&2; exit 2;;
        --help|-h)
            echo 'Usage: scripts/run_fft2_variants.sh --tag NEW_TAG [--variants FILE] [--ncu] [--dry-run]'
            echo 'Common sweep/profile options are accepted. Default: scripts/fft2_variants_default.txt.'
            echo 'Lines: n1=K c=C r=R [log2=16,17,...] [oop=0|1] [im=0|1] [pad=0|1|2]; # starts a comment.'
            echo 'n1/c/r: 0 = auto; im/pad: default 0.'
            exit 0;;
        *) common_args+=("$1"); shift;;
    esac
done
t1_parse "${common_args[@]}"
((with_ncu == 0 || skip_ncu == 0)) || { echo 'Choose --ncu or --skip-ncu' >&2; exit 2; }
case $variants_file in
    /*) ;;
    [[:alpha:]]:[\\/]*) variants_file=${variants_file//\\//};;
    *) variants_file="$invocation_dir/$variants_file";;
esac
[[ -r $variants_file ]] || { echo "Cannot read variants: $variants_file" >&2; exit 2; }
exponents=$(t1_exponents "$log2")
log2=${exponents//$'\n'/,}
profile_exponents=$(t1_exponents "$profile_log2")
profile_log2=${profile_exponents//$'\n'/,}
while read -r exponent; do
    ((exponent >= 16 && exponent <= 24)) || { echo 'fft2 variant exponents must be 16..24' >&2; exit 2; }
done <<< "$exponents"

# Validate the whole file, intersections and duplicate configs before any GPU work.
variant_n1=() variant_cols=() variant_rows=() variant_oop=() variant_sizes=() variant_tags=()
variant_index_mode=() variant_smem_padding=()
declare -A used_configs=()
line_number=0
while IFS= read -r line || [[ -n $line ]]; do
    line_number=$((line_number + 1))
    line=${line%%#*}; line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    read -r -a fields <<< "$line"
    declare -A parsed=()
    for field in "${fields[@]}"; do
        [[ $field =~ ^(n1|c|r|oop|im|pad|log2)=([0-9,]+)$ ]] || {
            echo "Invalid variant field on line $line_number: $field" >&2; exit 2;
        }
        key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
        [[ -z ${parsed[$key]:-} ]] || { echo "Duplicate $key on line $line_number" >&2; exit 2; }
        if [[ $key != log2 ]]; then
            if ! [[ $value =~ ^[0-9]+$ ]] || ((${#value} > 10)) || ((10#$value > 2147483647)); then
                echo "Invalid integer on line $line_number: $field" >&2; exit 2;
            fi
            value=$((10#$value))
        fi
        parsed[$key]=$value
    done
    [[ -n ${parsed[n1]:-} && -n ${parsed[c]:-} && -n ${parsed[r]:-} ]] || {
        echo "Line $line_number requires n1, c and r" >&2; exit 2;
    }
    oop=${parsed[oop]:-$fft2_out_of_place}
    ((oop == 0 || oop == 1)) || { echo "oop must be 0 or 1 on line $line_number" >&2; exit 2; }
    index_mode=${parsed[im]:-0} smem_padding=${parsed[pad]:-0}
    ((index_mode <= 1)) || { echo "im must be 0 or 1 on line $line_number" >&2; exit 2; }
    ((smem_padding <= 2)) || { echo "pad must be 0, 1 or 2 on line $line_number" >&2; exit 2; }
    selected=''
    selector=$(t1_exponents "${parsed[log2]:-$log2}")
    while read -r exponent; do
        ((exponent >= 16 && exponent <= 24)) || { echo "Variant size outside 16..24 on line $line_number" >&2; exit 2; }
        if [[ ,$log2, == *,"$exponent",* ]]; then
            split_n1=${parsed[n1]}
            ((split_n1 != 0)) || split_n1=$((1 << (exponent / 2)))
            split_n2=$(((1 << exponent) / (split_n1 > 0 ? split_n1 : 1)))
            if ((split_n1 < 256 || split_n1 > 4096 || (split_n1 & (split_n1 - 1)) != 0 ||
                 split_n2 < 256 || split_n2 > 4096)); then
                echo "Invalid N1/N2 split for log2=$exponent on line $line_number" >&2; exit 2;
            fi
            key="$exponent/${parsed[n1]}/${parsed[c]}/${parsed[r]}/$oop/$index_mode/$smem_padding"
            [[ -z ${used_configs[$key]:-} ]] || { echo "Duplicate variant config on line $line_number" >&2; exit 2; }
            used_configs[$key]=1
            selected+="${selected:+,}$exponent"
        fi
    done <<< "$selector"
    [[ -n $selected ]] || continue
    variant_n1+=("${parsed[n1]}"); variant_cols+=("${parsed[c]}"); variant_rows+=("${parsed[r]}")
    variant_oop+=("$oop"); variant_sizes+=("$selected")
    variant_index_mode+=("$index_mode"); variant_smem_padding+=("$smem_padding")
    printf -v worker_tag '%s.v%03d' "$tag" "${#variant_n1[@]}"
    variant_tags+=("$worker_tag")
done < "$variants_file"
((${#variant_tags[@]} > 0)) || { echo 'No variants match --log2' >&2; exit 2; }
t1_require_new "$out"
t1_require_new "results/$tag.baseline"
for worker_tag in "${variant_tags[@]}"; do t1_require_new "results/$worker_tag"; done
failed=0
run_step() { if t1_run "$@"; then return 0; else failed=1; fi; }
if ((dry_run == 0)); then
    mkdir -p "$out"
    printf 'tag,path,log2,n1,c,r,oop,im,pad\n' > "$out/variants.csv"
    for i in "${!variant_tags[@]}"; do
        t1_csv_row "${variant_tags[i]}" "variants/${variant_tags[i]##*.}" "${variant_sizes[i]}" "${variant_n1[i]}" \
            "${variant_cols[i]}" "${variant_rows[i]}" "${variant_oop[i]}" \
            "${variant_index_mode[i]}" "${variant_smem_padding[i]}" >> "$out/variants.csv"
    done
fi
run_args=(--log2 "$log2" --batch-modes "$batch_modes" --trials "$trials" --iters "$iters"
          --profile-log2 "$profile_log2" --profile-batch-modes "$profile_batch_modes"
          --ncu-max-kernels "$ncu_max_kernels" --ncu-library-max-kernels "$ncu_library_max_kernels")
((verify_fftw == 0)) || run_args+=(--verify-fftw)
workers=(env "FFT_BENCH=$bench_bin" "BWTEST=$bw_bin")
run_step git submodule update --init third_party/VkFFT
run_step make -B tools bench "TAG=$tag" "CUDA_ARCH=${CUDA_ARCH:-sm_80}" "WITH_FFTW=$verify_fftw"
run_step scripts/collect_env.sh --tag "$tag" "${run_args[@]}"
run_step scripts/run_bwtest.sh --tag "$tag" "${run_args[@]}"
run_step "${workers[@]}" scripts/run_sweep.sh --tag "$tag.baseline" "${run_args[@]}" --impls legacy,cufft,vkfft
merge_args=(--results "$out" --source "$out/variants/baseline")
if ((with_ncu)); then
    run_step scripts/export_vkfft_kernels.sh --tag "$tag" "${run_args[@]}"
    run_step "${workers[@]}" scripts/run_ncu.sh --tag "$tag.baseline" "${run_args[@]}" --impls legacy,cufft,vkfft
    merge_args+=(--ncu)
fi
run_step mkdir -p "$out/variants"
run_step mv -- "results/$tag.baseline" "$out/variants/baseline"
for i in "${!variant_tags[@]}"; do
    args=(--tag "${variant_tags[i]}" --log2 "${variant_sizes[i]}" --batch-modes "$batch_modes"
          --trials "$trials" --iters "$iters" --impls fft2 --fft2-n1 "${variant_n1[i]}"
          --fft2-tile-cols "${variant_cols[i]}" --fft2-tile-rows "${variant_rows[i]}"
          --fft2-index-mode "${variant_index_mode[i]}" --fft2-smem-padding "${variant_smem_padding[i]}")
    ((variant_oop[i] == 0)) || args+=(--fft2-out-of-place)
    ((verify_fftw == 0)) || args+=(--verify-fftw)
    run_step "${workers[@]}" scripts/run_sweep.sh "${args[@]}"
    if ((with_ncu)); then
        # Only profile sizes present in both this variant and the requested ncu set.
        selected=''
        IFS=',' read -r -a sizes <<< "${variant_sizes[i]}"
        for exponent in "${sizes[@]}"; do
            [[ ,$profile_log2, != *,"$exponent",* ]] || selected+="${selected:+,}$exponent"
        done
        if [[ -n $selected ]]; then
            run_step "${workers[@]}" scripts/run_ncu.sh "${args[@]}" --profile-log2 "$selected" \
                --profile-batch-modes "$profile_batch_modes" --skip-copy-profiles
        fi
    fi
    worker_dir="$out/variants/${variant_tags[i]##*.}"
    run_step mv -- "results/${variant_tags[i]}" "$worker_dir"
    merge_args+=(--source "$worker_dir")
done
run_step "$PYTHON" scripts/analysis/merge_variants.py "${merge_args[@]}"
analysis_args=(--tag "$tag")
((with_ncu)) || analysis_args+=(--skip-ncu)
run_step scripts/run_analysis.sh "${analysis_args[@]}"
exit "$failed"
