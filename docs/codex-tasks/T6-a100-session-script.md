# Codex Task T6 — one-shot A100 session script

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t6-a100-session`** from `codex/t2b-bench-fft2` (which already contains T1 + T2). Open a draft PR targeting `codex/t2b-bench-fft2`.

---

## Context
Read `CLAUDE.md` (Colab CLI section, measurement rules), `docs/plan.md`, `docs/measurement.md`, `scripts/run_t1_all.sh`, `scripts/run_fft2_variants.sh`, `fft2/README.md`. A100 time on Colab is paid per hour and allocations often fail, so the next A100 allocation must do **everything pending in one go**, survive partial failure, and stay within a known time budget. Claude starts it with `scripts/colab/run.sh --gpu A100 --cmd 'bash scripts/a100_session.sh --tag TAG' --fetch results/TAG`.

## Hard constraints
1. Only add: `scripts/a100_session.sh`, `scripts/a100_session.d/` (helpers/config), `tests/test_a100_session.py`, a section in `docs/measurement.md`. Do not modify other scripts' behaviour, `fft2/`, `bench/`, `results/`, `scripts/colab/`, `docs/plan.md`.
2. Commit and push after each deliverable. No performance claims.

## Deliverables
`scripts/a100_session.sh --tag TAG [--budget-min 90] [--only STEP,...] [--skip STEP,...] [--dry-run] [--allow-non-a100]`
1. **Step 0 guard**: `nvidia-smi` GPU name must be `A100-SXM4-40GB` unless `--allow-non-a100` (then tag gets suffix `_nonA100` and every summary says smoke-only). Record env (reuse `collect_env.sh`).
2. **Ordered steps**, each writing `results/TAG/session_status.csv` (`step,status,start,end,seconds,log`), each in its own log, a failing step never aborts later independent steps:
   1. `fft2_gate` — `make -C fft2 CUDA_ARCH=sm_80 && fft2/fft2_test` and, if supported by the binary, `fft2/fft2_test --variants`.
   2. `t1_full` — `run_t1_all.sh --tag TAG` (full).
   3. `fft2_variants` — `run_fft2_variants.sh` with the default variants file, sweep + ncu; if `fft2` exposes `index_mode`/`smem_padding`/`radix_mode` options (T4a/T4b may or may not be merged — detect via `fft2/fft2.h` or a `--help` flag), include them; otherwise skip those axes with a note.
   4. `report` — `scripts/make_report.sh --tag TAG` if it exists (T5a), else skip with note.
3. **Budget**: before each step, estimate its duration (from `--dry-run` counts × per-capture constants in a config file; document the constants as rough guesses, to be recalibrated after the first run) and skip optional steps that would exceed `--budget-min`; record `skipped_budget`.
4. **Resumability**: re-running with the same tag skips steps already `ok` (so a second allocation can finish a cut-off session).
5. **Packaging**: at the end (also on failure via `trap`), write `results/TAG/SESSION_SUMMARY.md` (status table, GPU, what to fetch) and a `results/TAG/compact/` subset suitable for committing (CSVs, `limits.json`, ncu summaries, manifests, report; no `.ncu-rep`, no build dirs).
6. Tests (CPU): `--dry-run` prints the ordered plan with estimates; status CSV handling; resume skipping; budget skipping; non-A100 guard (mock `nvidia-smi` via PATH).

## Gate
`pytest tests -q`, `shellcheck scripts/a100_session.sh scripts/a100_session.d/*.sh`, `scripts/a100_session.sh --tag x --dry-run --allow-non-a100` succeeds on a CPU machine.

## Acceptance criteria
- [ ] All above; `docs/measurement.md` section "A100 session".
- [ ] PR description shows the dry-run output and the estimated total minutes.
