#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
t1_parse "$@"
failed=0
if ! t1_run "$PYTHON" scripts/analysis/derive.py --raw "$out/sweep/raw.csv" --pass-floor "$out/bandwidth/pass_floor.csv" --output "$out/sweep/derived.csv"; then failed=1; fi
if ! t1_run "$PYTHON" scripts/analysis/plot_sweep.py --input "$out/sweep/derived.csv" --plots "$out/plots" --summary "$out/summary.md"; then failed=1; fi
if ((skip_ncu == 0)); then
    if ! t1_run "$PYTHON" scripts/analysis/ncu_summary.py --results "$out"; then failed=1; fi
fi
exit "$failed"
