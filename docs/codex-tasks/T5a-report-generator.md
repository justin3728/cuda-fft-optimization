# Codex Task T5a — results → Markdown bottleneck report generator

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t5a-report`** from `codex/t1-measurement-tooling`. Open a draft PR targeting `codex/t1-measurement-tooling`.

---

## Context
Read `CLAUDE.md`, `docs/plan.md` §1 (M1 definition item 3), `docs/measurement.md`, and the L4 smoke outputs in `results/smoke_l4_20261111/` (on `main`; copy them into a test fixture). M1 requires a README bottleneck analysis: for every kernel of every implementation, time, bytes, % of the **measured** HBM/L2 limit, and the remaining gap, plus a before/after comparison. This is the core of the portfolio ("how do you know it's fast"), so the tables must be generated from `results/<tag>/`, never typed by hand.

## Hard constraints
1. Only add/modify: `scripts/analysis/make_report.py` (new), `scripts/make_report.sh` (new, thin wrapper), `tests/test_make_report.py` (new), `tests/fixtures/report/` (new), and a section in `docs/measurement.md`. Do not touch `bench/`, `fft2/`, other analysis scripts' behaviour (importing their helpers is fine), `results/`, `README.md`, `docs/plan.md`.
2. The generator never invents or interpolates numbers: every cell comes from a file; missing → `n/a` with a footnote saying which file/column was missing.
3. Commit and push after each item.

## Deliverables
`scripts/make_report.sh --tag TAG [--baseline-tag OLD] [--impls legacy,cufft,vkfft,fft2] [--out FILE]` → Markdown with:
1. **Header**: GPU name, driver/CUDA/ncu versions, clocks, ncu cache/clock settings, date — from env capture / `limits.json` / ncu index. Big warning banner if GPU ≠ `A100-SXM4-40GB` ("smoke test, not official numbers").
2. **Limits table**: measured HBM read/write/copy, L2 plateau, per-size pass floor (`pass_floor.csv`).
3. **Sweep table** per (N, batch): median hot & cold time per impl, speedup vs cuFFT, "passes-equivalent" = time / pass floor, correctness status.
4. **Per-kernel table** per profiled config: kernel, time, DRAM R/W bytes ÷ ideal (calibrated with `copy_calibration.csv`), L2 bytes, `pct_mixed_hbm_limit`, `pct_l2_limit`, occupancy, bank conflicts, top 2 stall reasons; L2-resident note when `working_set_fits_l2`.
5. **Gap column**: for each config, `impl time − (passes × pass floor)` in µs and %, i.e. how far from the bandwidth bound.
6. **Before/after** (when `--baseline-tag`): side-by-side deltas for configs present in both.
7. Optional `--plots` to embed existing PNGs by relative path.

## Tests
Fixture built from `results/smoke_l4_20261111/` (trim to keep small) → golden Markdown snapshot test; tests for: missing files → `n/a` + footnote; non-A100 banner; before/after with partially overlapping configs; fft2 rows with an `impl_detail` column present or absent (T2b adds it in parallel — handle both).

## Gate
`pytest tests -q`, `shellcheck scripts/make_report.sh`, and `scripts/make_report.sh --tag smoke_l4_20261111` run against the real `results/` dir produces a report without exceptions (attach it in the PR description).

## Acceptance criteria
- [ ] All of the above; `docs/measurement.md` section "Report".
