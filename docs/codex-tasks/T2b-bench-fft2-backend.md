# Codex Task T2b — `fft2` as the 4th backend of the measurement harness

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t2b-bench-fft2`** from `codex/t1-measurement-tooling`, then `git merge origin/codex/t2-two-pass-v1` into it (they touch disjoint directories; if any conflict appears, stop and report it in the PR). Open a draft PR **targeting `codex/t1-measurement-tooling`** and say in the description that it also contains PR #2's commits until both merge.

---

## Context
Read `CLAUDE.md`, `docs/plan.md`, `docs/measurement.md`, `fft2/README.md`. The harness (`bench/fft_bench.cu`, `bench/backends/*`) currently knows `legacy`, `cufft`, `vkfft`. The new 2-pass implementation is `fft2::Plan` (`fft2/fft2.h`). We need it in the same sweep / ncu / analysis pipeline so every future A100 run produces a 4-way comparison automatically, and so tuning variants of fft2 can be A/B'd in a single GPU allocation.

## Hard constraints
1. Do not modify anything under `fft2/` (other PRs are changing it), nor protected legacy files (`fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`), nor `results/`, `docs/plan.md`.
2. You may modify `bench/`, `scripts/`, `tests/`, the root `Makefile` include hook only if unavoidable, and `docs/measurement.md`.
3. Commit and push after each deliverable. No performance claims.

## Deliverables
1. `bench/backends/fft2.cu` — `make_fft2(PlanOptions)` backend; `supports()` = N in [2^16, 2^24] power of two, batch ≥ 1, memory fits; buffer allocated by the backend; `execute()` = `plan.execute(buf, buf, stream)` (in-place) — also add an `--fft2-out-of-place` flag that uses a second buffer, since in-place vs out-of-place may differ in traffic.
2. CLI: `--impl fft2` plus `--fft2-n1 K --fft2-tile-cols C --fft2-tile-rows R` (0 = auto) passed into `PlanOptions`. Record the resolved `plan.describe()` (actual N1/N2/tiles) in the sweep CSV as a new column `impl_detail` (empty for other backends). Make the impl name in CSV/NVTX distinguish variants, e.g. `fft2[n1=1024,c=8,r=8]`.
3. Build: add `fft2/fft2.cu` to the `fft_bench` target in `bench/Makefile.inc` (compile it from its own location; do not copy it).
4. Scripts: `run_sweep.sh` / `run_ncu.sh` / `run_t1_all.sh` include `fft2` in the default impl list; ncu NVTX filtering captures exactly the 2 fft2 kernels per execute; `ncu_summary.py` and `plot_sweep.py` handle the 4th impl and the `impl_detail` column (plots: one colour per impl; fft2 variants as separate series).
5. `scripts/run_fft2_variants.sh --tag TAG --variants FILE` — reads a small text file of variant lines (`n1=1024 c=8 r=8`, …), runs sweep (and optionally ncu with `--ncu`) for each, all in one process run, so one A100 allocation covers many variants. Include `scripts/fft2_variants_default.txt` with the auto policy plus ~6 sensible alternatives per size class based on `fft2/README.md` shared-memory budgets.
6. Tests (CPU): dry-run of `run_t1_all.sh` lists fft2 configs; dry-run of `run_fft2_variants.sh` produces the expected command list; analysis tests with a fixture containing fft2 rows and `impl_detail`.

## Gate
CPU: `pytest tests -q`, `shellcheck scripts/*.sh`, `make bench TAG=t2b CUDA_ARCH=sm_80` and `sm_89` compile with zero warnings.
GPU (Claude, later): `scripts/run_t1_all.sh --tag t2b_l4 --quick` on L4 → `stage_status.csv` all OK and fft2 rows `ok`.

## Acceptance criteria
- [ ] All deliverables, CPU gate green, PR description lists what still needs GPU confirmation.
- [ ] `docs/measurement.md` updated (new impl, `impl_detail`, variants script).
