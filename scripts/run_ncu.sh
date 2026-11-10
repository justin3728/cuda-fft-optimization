#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
failed=0
if ((dry_run == 0)); then
    mkdir -p "$out/ncu"
    t1_require_new "$out/ncu/index.csv"
    printf 'impl,N,batch,batch_mode,cache_control,raw_csv,status\n' > "$out/ncu/index.csv"
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
    local base="$out/ncu/$id" status=ok code=0
    local -a command=("$NCU" --set full --cache-control "$cache" --clock-control none --replay-mode kernel
        --target-processes all --kernel-name-base demangled --nvtx --nvtx-include "$filter"
        "${metric_args[@]}" --export "$base" "$@")
    t1_print "${command[@]}"
    t1_print "$NCU" --import "$base.ncu-rep" --page raw --csv --print-units base
    if ((dry_run)); then return 0; fi
    t1_print "${command[@]}" >> "$out/ncu/commands.txt"
    if "${command[@]}" > "$base.capture.log" 2>&1; then code=0; else code=$?; fi
    if grep -q 'ERR_NVGPUCTRPERM' "$base.capture.log"; then
        printf '%s,%s,%s,%s,%s,%s,permission_error\n' "$impl" "$n" "$batch" "$mode" "$cache" "$id.csv" >> "$out/ncu/index.csv"
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
        fi
    fi
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$impl" "$n" "$batch" "$mode" "$cache" "$id.csv" "$status" >> "$out/ncu/index.csv"
}

IFS=',' read -r -a implementations <<< "$impls"
IFS=',' read -r -a modes <<< "$profile_batch_modes"
exponents=$(t1_exponents "$profile_log2")
while read -r exponent; do
    n=$((1 << exponent))
    for mode in "${modes[@]}"; do
        batch=$(t1_batch "$n" "$mode")
        for impl in "${implementations[@]}"; do
            id="${impl}_N${n}_b${batch}_${mode}_cache_all"
            if [[ $impl == legacy ]] && ((n > 1048576)); then
                echo "unsupported: legacy N=$n exceeds 2^20"
                if ((dry_run == 0)); then printf '%s,%s,%s,%s,all,%s,unsupported\n' "$impl" "$n" "$batch" "$mode" "$id.csv" >> "$out/ncu/index.csv"; fi
                continue
            fi
            capture "$impl" "$n" "$batch" "$mode" all "$id" "prof\\/${impl}\\/N${n}\\/b${batch}/" \
                "$bench_bin" --tag "$tag" --profile --impls "$impl" --n "$n" --batch "$batch" --batch-modes "$mode"
            if ((n == 1048576 && batch == 1)); then
                capture "$impl" "$n" "$batch" "$mode" none "${impl}_N${n}_b${batch}_${mode}_cache_none" "prof\\/${impl}\\/N${n}\\/b${batch}/" \
                    "$bench_bin" --tag "$tag" --profile --impls "$impl" --n "$n" --batch "$batch" --batch-modes "$mode"
            fi
        done
    done
done <<< "$exponents"
# Both sizes get the primary cold-replay run. The L2-sized copy also gets a
# no-flush run, since cache-control=all deliberately destroys its hot plateau.
capture bwcopy 0 0 WS4096 all bwcopy_WS4096_cache_all 'prof\/bwcopy\/WS4096/' "$bw_bin" --tag "$tag" --profile-copy-mib 4096
capture bwcopy 0 0 WS16 all bwcopy_WS16_cache_all 'prof\/bwcopy\/WS16/' "$bw_bin" --tag "$tag" --profile-copy-mib 16
capture bwcopy 0 0 WS16 none bwcopy_WS16_cache_none 'prof\/bwcopy\/WS16/' "$bw_bin" --tag "$tag" --profile-copy-mib 16
if ! t1_run "$PYTHON" scripts/analysis/ncu_summary.py --results "$out" --retain-reports; then failed=1; fi
exit "$failed"
