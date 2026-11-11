# Codex Task T3 — GitHub Actions CI (no GPU)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t3-ci` from `main`**, open a separate draft PR. Small task (~1 hour).

---

## Context
Read `CLAUDE.md` and `docs/plan.md`. Two PRs are open and unmerged: #1 `codex/t1-measurement-tooling` (adds `bench/`, `scripts/`, `tools/`, `tests/`, VkFFT submodule) and #2 `codex/t2-two-pass-v1` (adds `fft2/`). CI must work on `main` today **and** keep working after those merge, so every job must skip cleanly when its directory does not exist yet.

## Hard constraints
1. Only add files under `.github/` (and optionally `ci/` for helper scripts). Do not touch any other file.
2. No GPU anywhere; nothing in CI may need one.
3. Commit and push to `codex/t3-ci` after each job works (WIP commits fine).

## Deliverables
`.github/workflows/ci.yml`, triggered on `pull_request` and `push` to `main`, with these jobs:
1. **python** — Python 3.12; if `tests/` exists: `pip install -r scripts/analysis/requirements.txt pytest` then `pytest tests -q`; if `fft2/reference` exists: `pytest fft2/reference -q`. Skip with a visible `::notice::` when absent.
2. **shell** — `bash -n` and `shellcheck` on every `*.sh` under `scripts/` (skip if none); if `scripts/run_t1_all.sh` exists run `scripts/run_t1_all.sh --tag ci --dry-run` and `--quick --dry-run`.
3. **cuda-compile** — container `nvidia/cuda:13.0.x-devel-ubuntu24.04` (pick an existing tag; note it in the PR). Compile-only, no execution:
   - `make -C fft2 CUDA_ARCH=sm_80` and `CUDA_ARCH=sm_89` if `fft2/` exists (it uses `-Werror=all-warnings`, so this is a real warning gate);
   - `git submodule update --init third_party/VkFFT` and `make bench tools TAG=ci CUDA_ARCH=sm_80` if `bench/` exists;
   - legacy: `make -B CUDA_ARCH=sm_80` (legacy default sm_61 does not build on CUDA 13 — do not change the legacy Makefile).
   Cache apt/pip where easy; keep the job under ~15 min.
4. **notebooks** — validate every `notebooks/*.ipynb` is valid JSON with `nbformat` and has no stored outputs larger than 1 MB (warn only).

## Acceptance criteria
- [ ] Workflow green on the PR against current `main` (absent dirs → skipped with notice, not failed).
- [ ] In the PR description, show a run of the same workflow on a temporary branch that merges `codex/t1-measurement-tooling` and `codex/t2-two-pass-v1` (do not push that merge anywhere permanent; delete the temp branch after) — all jobs green, or list exactly which step fails and why.
- [ ] `README`-style comment block at the top of `ci.yml` explaining each job in 1 line.
