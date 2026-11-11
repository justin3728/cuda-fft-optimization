# Codex Task T8 — portfolio README skeleton (no numbers)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t8-readme`** from `main`. Open a draft PR targeting `main`.

---

## Context
Read `CLAUDE.md`, `docs/plan.md`, `docs/optimization-log.md`, the current `README.md`, and skim the open PRs' docs (`git show origin/codex/t1-measurement-tooling:docs/measurement.md`, `git show origin/codex/t2-two-pass-v1:fft2/README.md`). This repo is the owner's main job-hunting portfolio (target readers: GPU/HPC hiring managers at e.g. NVIDIA, Google). The final README must answer "how do you know it's fast?" with measured data. The data does not exist yet (A100 runs pending). This task writes the **structure and all non-numeric content**, with clearly marked placeholders that the report generator (`scripts/make_report.sh`, PR #5) will fill later.

## Hard constraints
1. Only modify `README.md` and add `docs/architecture.md` plus diagrams as **Mermaid** blocks or SVG files under `docs/img/`. Do not touch code, `results/`, `docs/plan.md`, `docs/optimization-log.md`.
2. **No performance numbers anywhere**, not even old ones, except quoting existing committed files with their path and the label "legacy harness, superseded" if needed. Every future number is a placeholder like `<!-- REPORT:sweep_table -->` with a one-line note on which `results/` file will fill it.
3. Keep the legacy README content that is still true (move it to a "Legacy implementation" section); remove claims the new measurement methodology invalidates (see plan.md F2), or mark them.
4. Write in English; concise, technical, no marketing adjectives. Commit and push after each section.

## Deliverables
README sections:
1. One-paragraph summary + key result placeholder (`<!-- REPORT:headline -->`).
2. **Why this is hard**: FP64 FFT is memory-bound; the pass-count argument (5 passes legacy → 2 passes) with the formula `t_min ≈ passes × 2 × 16·N·batch / BW_measured`.
3. **Method — how we know it's fast**: measured HBM/L2 limits (bwtest), pass floor, calibration, ncu per-kernel achievement, L2-resident caveat, A100-only official numbers. Link `docs/measurement.md`.
4. **Design**: 2-pass decomposition (the index formula from `fft2/README.md`), tiles C/R and coalescing, shared-memory staging instead of transpose, batch as grid dimension; Mermaid diagram of data flow per pass. Put the deeper version in `docs/architecture.md` (index maps, shared-memory budgets, tuning variants H9–H11 as hypotheses).
5. **Results** placeholders: limits table, sweep table (legacy / cuFFT / VkFFT / fft2), per-kernel bottleneck table, before/after, remaining-gap discussion.
6. **Optimization log highlights**: link to `docs/optimization-log.md`, describe the hypothesis → ncu → outcome format.
7. **Reproduce**: Colab A100 workflow (`scripts/colab/run.sh`, `notebooks/`), build commands with `CUDA_ARCH`, tests (`pytest`, `fft2_test`), CI badge for `.github/workflows/ci.yml`.
8. **Repository layout** tree, **Legacy implementation**, **Limitations / future work** (non-power-of-two, FP32, inverse, multi-GPU — just listed).

## Acceptance criteria
- [ ] Renders correctly on GitHub (check Mermaid syntax); all internal links valid (`grep`-check paths exist on main or are marked "after PR #N merges").
- [ ] `grep -nE '[0-9]+(\.[0-9]+)? ?(µs|us|ms|GB/s|TB/s|%|x faster)' README.md docs/architecture.md` returns only lines inside placeholders or explicitly labelled legacy/superseded quotes — paste the grep output in the PR.
