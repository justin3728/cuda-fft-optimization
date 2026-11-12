# Codex Task T5a-fix-1 — report generator must keep labelled fft2 variants

> Paste everything below the line into Codex. Create branch **`codex/t5a-fix-1` from `main`**, open a draft PR. Small task (< 1 hour).

---

## Context
PR #5 (T5a, `scripts/analysis/make_report.py`) and PR #7 (T2b) are both merged on `main`. T2b writes the fft2 implementation name as a **label** such as `fft2[n1=0,c=0,r=0]` or `fft2[n1=1024,c=4,r=8,oop=1]` in `sweep/raw.csv`, `ncu/index.csv`, `ncu/config_totals.csv` and the per-kernel summaries. `make_report.py` filters with exact matches against the families `legacy,cufft,vkfft,fft2` (`row.data.get("impl") == impl` / `in impls`, e.g. `sweep_entries`, `profiles`, `comparison_section`), so **every fft2 row is dropped** from the report.

## Hard constraints
1. Only touch `scripts/analysis/make_report.py`, `tests/test_make_report.py`, `tests/fixtures/report/`. Commit and push after each step.
2. No numbers invented; `n/a` + footnote rules stay.

## Fix
- `--impls` keeps taking families. Match a row when `impl.split("[", 1)[0]` is in the selected families.
- Within one family, every distinct label is its own series/row (ordered: auto `fft2[n1=0,c=0,r=0]` first, then label order), in the sweep, per-kernel and before/after sections. Before/after keys use the full label.
- Speedup vs cuFFT stays relative to the `cufft` row of the same config/timing.

## Tests
Fixture with two fft2 labels (auto + one explicit, one of them `oop=1`) in sweep, ncu index and totals: both appear in every section; `--impls cufft` excludes them; before/after with a label present only on one side shows it as non-overlapping. Update the golden snapshot only where fft2 rows are added.

## Gate
`pytest tests -q`, `shellcheck scripts/*.sh`.
