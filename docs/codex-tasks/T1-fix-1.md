# Codex Task T1-fix-1 — review fixes for PR #1 (measurement tooling)

> Paste everything below the line into Codex. Work on the existing branch `codex/t1-measurement-tooling` (PR #1) and push to it; do not open a new PR.

---

## Context

PR #1 was reviewed and smoke-tested end to end on a Colab **L4** (CUDA 13.0, driver 580.82.07, ncu 2025.3.1) with `scripts/run_t1_all.sh --quick`, `CUDA_ARCH=sm_89`. **All 7 stages passed**, builds with zero warnings under CUDA 13, every sweep row is `ok` (rel L2 err ≤ 7.2e-16), legacy rows above 2^20 are `unsupported`, VkFFT's sign convention matches cuFFT, VkFFT export works (2/2/3 kernels for N=2^16/2^20/2^24), and NVTX filtering captured the right kernels for all three implementations. A compact copy of the outputs is on `main` under `results/smoke_l4_20261111/` — read it, especially `ncu/legacy_N1048576_b1_b1_cache_all.md` and `ncu/copy_calibration.csv`.

The constraints from the original T1 task still apply: don't touch `fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu` or existing `results/`; don't fabricate numbers.

## Fixes (in priority order)

### F1 (must) — ncu runtime explodes on legacy batched configs
The legacy backend's batch is a host loop: legacy N=2^16 with `t25` is 512 batches × 5 kernels = 2,560 kernels, each replayed for `--set full`. The full run cannot meet the 45-minute target.
- For any profiled config whose expected kernel count is large, capture only a bounded prefix (e.g. `--launch-count` so that at most the first K complete executions/batches are captured; K configurable, default so that ≤ ~50 kernels per config) and record `captured_kernels`, `expected_kernels` (or `sampled=true`) in `ncu/index.csv` and the summary.
- `ncu_summary.py` must then report per-kernel metrics as-is and scale per-config totals (time, DRAM bytes, passes) by the sampling ratio, labelled clearly as extrapolated. cuFFT/VkFFT batched configs launch few kernels and should normally not be sampled.
- Add a dry-run/CPU test proving the legacy `t25` N=2^16 config produces a bounded ncu command.

### F2 (must) — "% of measured HBM" is wrong for read-dominated or L2-resident kernels
Observed on L4: legacy `transpose_opt` at N=2^20 shows `pct_measured_hbm_copy = 115%`. Its DRAM traffic is ~19 MB read and ~12 KB written: the 16 MiB output stays in the 48 MB L2 and is written back after the kernel ends, so dividing by the *copy* peak is not meaningful. `copy_calibration.csv` shows the same effect (WS16, cache none: DRAM factor 0.002).
- Keep the existing columns, and add `pct_mixed_hbm_limit = (dram_read_bytes / hbm_read_GBs + dram_write_bytes / hbm_write_GBs) / duration` (as %) — i.e., the time an ideal kernel moving exactly these DRAM bytes would need at the measured read/write peaks, divided by the actual duration.
- Add the same for L2: `pct_l2_limit` using `lts_bytes` and the L2 plateau (read plateau for read-heavy, or the analogous mixed formula if you can split L2 read/write sectors from available metrics; document what you used).
- Add a per-config flag `working_set_fits_l2` (= 2 × 16 × N × batch ≤ L2 size from `limits.json`) and print a note in the Markdown summary when true: "DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics."
- Update `docs/measurement.md` with these definitions.

### F3 (should) — cold-mode L2 flush biases cold times upward
`L2Flush` *writes* a 2×L2 buffer, leaving the L2 full of dirty lines that the timed kernel must then write back. Flush with a **read** pass over a 2×L2 buffer (e.g. `read16` with a sink) so the flush evicts without leaving dirty data. Apply to the sweep and the pass floors (same code path). Document it.

### F4 (should) — VkFFT init vs. timing stream ordering
VkFFT is initialized with `stream_ == nullptr` (legacy default stream) while timing uses a `cudaStreamNonBlocking` stream, which does not synchronize with stream 0. Add `cudaDeviceSynchronize()` (checked) after `initializeVkFFT` in `plan()`.

### F5 (should) — shared-memory columns are always NA
`ncu_summary.py` warns `unknown byte unit 'byte/block'; emitting NA`, so `static_smem_bytes`, `dynamic_smem_bytes`, `smem_bytes` are NA for every kernel. Support `byte/block` (and any other unit forms seen in the fixture of real ncu 2025.3 output — add one to `tests/fixtures`).

### F6 (nit) — move `cufftSetStream` out of the timed path
Call `cufftSetStream` once per stream change instead of every `execute()` (cache the last stream). Same for the VkFFT stream pointer if applicable.

## Acceptance criteria

- [ ] All fixes above, each with a test where testable on CPU (F1 command bounding, F2 formulas incl. the 115%-type case, F5 unit parsing). `pytest tests/` passes; `bash -n` + `shellcheck` clean; `--dry-run` works.
- [ ] Full-run estimate: `run_t1_all.sh --dry-run` (full, not quick) prints the number of ncu kernel captures per config; total ≤ ~400 kernel captures.
- [ ] No changes to protected files or existing `results/`.
- [ ] `docs/measurement.md` updated (F1 sampling, F2 columns + L2-resident note, F3 flush).
- [ ] PR #1 description updated with a "Fix round 1" section listing what changed and what still needs GPU confirmation.
- [ ] Do **not** edit `docs/plan.md` this round.

Verified later on GPU by the owner/Claude: quick run still all-OK; full run ≤ 45 min on A100; `pct_mixed_hbm_limit` ≤ ~100% for every kernel.
