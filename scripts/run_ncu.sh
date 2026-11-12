#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
failed=0
capture_budget=0
if ((dry_run == 0)); then
    mkdir -p "$out/ncu"
    t1_require_new "$out/ncu/index.csv"
    printf 'impl,N,batch,batch_mode,cache_control,raw_csv,status,captured_kernels,expected_kernels,sampled,capture_limit,kernels_per_batch,impl_detail\n' > "$out/ncu/index.csv"
    t1_print "$NCU" --version > "$out/ncu/commands.txt"
    "$NCU" --version > "$out/ncu/version.txt" 2>&1 || { cat "$out/ncu/version.txt"; exit 1; }
fi
t1_print "$NCU" --query-metrics --query-metrics-mode all
t1_print "$NCU" --set full --list-metrics
t1_print "$PYTHON" scripts/analysis/ncu_summary.py --query-file "$out/ncu/metric_query.txt" --query-file "$out/ncu/section_metrics.txt" --metrics-out "$out/ncu/metrics.txt"
metric_args=()
if ((dry_run == 0)); then
    t1_print "$NCU" --query-metrics --query-metrics-mode all >> "$out/ncu/commands.txt"
    "$NCU" --query-metrics --query-metrics-mode all > "$out/ncu/metric_query.txt" 2>&1 || echo 'WARNING: metric query failed; full set will still be attempted' >&2
    t1_print "$NCU" --set full --list-metrics >> "$out/ncu/commands.txt"
    "$NCU" --set full --list-metrics > "$out/ncu/section_metrics.txt" 2>&1 || echo 'WARNING: section metric listing failed' >&2
    "$PYTHON" scripts/analysis/ncu_summary.py --query-file "$out/ncu/metric_query.txt" --query-file "$out/ncu/section_metrics.txt" --metrics-out "$out/ncu/metrics.txt"
    metrics=$(<"$out/ncu/metrics.txt")
    [[ -z $metrics ]] || metric_args=(--metrics "$metrics")
else
    echo 'The queried, supported metrics from metrics.txt are appended to --set full at execution time.'
fi

capture() {
    local impl=$1 n=$2 batch=$3 mode=$4 cache=$5 id=$6 filter=$7
    shift 7
    local base="$out/ncu/$id" status=ok code=0 impl_detail=''
    local captured=NA expected=NA sampled=auto capture_limit=$ncu_library_max_kernels kernels_per_batch=NA
    if [[ $impl == fft2* ]]; then
        expected=2; capture_limit=2; sampled=false
    elif [[ $impl == bwcopy ]]; then
        expected=1; capture_limit=1; sampled=false
    fi
    capture_budget=$((capture_budget + capture_limit))
    printf 'NCU capture plan: impl=%s N=%s batch=%s cache=%s expected_kernels=%s capture_limit=%s sampled=%s\n' \
        "$impl" "$n" "$batch" "$cache" "$expected" "$capture_limit" "$sampled"
    local -a command=("$NCU" --set full --cache-control "$cache" --clock-control none --replay-mode kernel
        --target-processes all --kernel-name-base demangled --nvtx --nvtx-include "$filter"
        --launch-count "$capture_limit" "${metric_args[@]}" --export "$base" "$@")
    t1_print "${command[@]}"
    t1_print "$NCU" --import "$base.ncu-rep" --page raw --csv --print-units base
    if ((dry_run)); then return 0; fi
    t1_print "${command[@]}" >> "$out/ncu/commands.txt"
    if "${command[@]}" > "$base.capture.log" 2>&1; then code=0; else code=$?; fi
    if grep -q 'ERR_NVGPUCTRPERM' "$base.capture.log"; then
        t1_csv_row "$impl" "$n" "$batch" "$mode" "$cache" "$id.csv" permission_error \
            "$captured" "$expected" "$sampled" "$capture_limit" "$kernels_per_batch" "$impl_detail" >> "$out/ncu/index.csv"
        cat "$base.capture.log" >&2
        echo 'ERR_NVGPUCTRPERM: GPU counters are restricted by the host driver.' >&2
        echo "Ask the host admin to run the recorded ncu command with sudo -E (use the absolute ncu/binary paths). Exact commands: $out/ncu/commands.txt" >&2
        echo 'Or have the admin set: options nvidia NVreg_RestrictProfilingToAdminUsers=0 in /etc/modprobe.d/nvidia-profiler.conf, then reload the NVIDIA modules or reboot.' >&2
        echo 'On a rented/container GPU this must be configured on the host; container root alone may be insufficient.' >&2
        exit 77
    fi
    if ((code != 0)) || [[ ! -s $base.ncu-rep ]]; then
        status=error; failed=1
        tail -n 30 "$base.capture.log" >&2
    else
        t1_print "$NCU" --import "$base.ncu-rep" --page raw --csv --print-units base >> "$out/ncu/commands.txt"
        if ! "$NCU" --import "$base.ncu-rep" --page raw --csv --print-units base > "$base.csv" 2> "$base.export.log"; then
            status=error; failed=1; cat "$base.export.log" >&2
        elif ! captured=$("$PYTHON" scripts/analysis/ncu_summary.py --count-kernels "$base.csv"); then
            status=error; failed=1; captured=NA
            echo "Could not count captured kernels in $base.csv" >&2
        elif [[ ! $captured =~ ^[1-9][0-9]*$ ]]; then
            status=error; failed=1; captured=NA
            echo "Invalid captured-kernel count for $base.csv" >&2
        elif [[ $impl == fft2* ]]; then
            if ! "$PYTHON" scripts/analysis/ncu_summary.py --check-fft2-capture "$base.csv"; then
                status=error; failed=1
                echo "Expected exactly fft2 pass1_columns and pass2_rows; captured=$captured" >&2
            fi
        elif [[ $impl == bwcopy ]]; then
            if ((captured != 1)); then
                status=error; failed=1
                echo "Expected exactly one bandwidth-copy kernel; captured=$captured" >&2
            fi
        elif ((captured >= capture_limit)); then
            status=error; failed=1; expected=NA; sampled=unknown
            echo "Library capture reached its safety limit ($capture_limit); total kernel count is unknown. Increase --ncu-library-max-kernels; refusing to extrapolate a potentially truncated library profile." >&2
        else
            expected=$captured; sampled=false
        fi
    fi
    impl_detail=$(sed -n 's/^impl_detail=//p' "$base.capture.log" | tail -n 1)
    t1_csv_row "$impl" "$n" "$batch" "$mode" "$cache" "$id.csv" "$status" \
        "$captured" "$expected" "$sampled" "$capture_limit" "$kernels_per_batch" "$impl_detail" >> "$out/ncu/index.csv"
}

IFS=',' read -r -a implementations <<< "$impls"
IFS=',' read -r -a modes <<< "$profile_batch_modes"
exponents=$(t1_exponents "$profile_log2")
while read -r exponent; do
    n=$((1 << exponent))
    for mode in "${modes[@]}"; do
        batch=$(t1_batch "$n" "$mode")
        for impl in "${implementations[@]}"; do
            label=$impl
            [[ $impl != fft2 ]] || label=$(t1_fft2_name)
            id="${label}_N${n}_b${batch}_${mode}"
            if [[ $impl == fft2 ]] && ((exponent < 16 || exponent > 24)); then
                echo "unsupported: $impl N=$n outside its supported range"
                if ((dry_run == 0)); then t1_csv_row "$label" "$n" "$batch" "$mode" all "${id}_cache_all.csv" unsupported 0 0 false 0 NA '' >> "$out/ncu/index.csv"; fi
                continue
            fi
            filter=$(t1_nvtx_filter "prof/$label/N$n/b$batch")
            profile_args=("$bench_bin" --tag "$tag" --profile --impls "$impl" --n "$n" --batch "$batch" --batch-modes "$mode" "${fft2_args[@]}")
            capture "$label" "$n" "$batch" "$mode" all "${id}_cache_all" "$filter" "${profile_args[@]}"
            if ((n == 1048576 && batch == 1)); then
                capture "$label" "$n" "$batch" "$mode" none "${id}_cache_none" "$filter" "${profile_args[@]}"
            fi
        done
    done
done <<< "$exponents"
# Both sizes get the primary cold-replay run. The L2-sized copy also gets a
# no-flush run, since cache-control=all deliberately destroys its hot plateau.
if ((skip_copy_profiles == 0)); then
capture bwcopy 0 0 WS4096 all bwcopy_WS4096_cache_all 'prof\/bwcopy\/WS4096/' "$bw_bin" --tag "$tag" --profile-copy-mib 4096
capture bwcopy 0 0 WS16 all bwcopy_WS16_cache_all 'prof\/bwcopy\/WS16/' "$bw_bin" --tag "$tag" --profile-copy-mib 16
capture bwcopy 0 0 WS16 none bwcopy_WS16_cache_none 'prof\/bwcopy\/WS16/' "$bw_bin" --tag "$tag" --profile-copy-mib 16
fi
printf 'NCU total capture upper bound: %s kernels (actual library counts are recorded after capture)\n' "$capture_budget"
if ! t1_run "$PYTHON" scripts/analysis/ncu_summary.py --results "$out" --retain-reports; then failed=1; fi
exit "$failed"
