# Codex Task T4e — memory-level parallelism in the fft2 load/store phases (H15)

> Branch **`codex/t4e-fft2-load-mlp`** from `main`, **after T4d merges**. PR to `main`. Effort high.

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, and `docs/optimization-log.md` L006.
- At 2^24, every fft2 variant uses 128 KiB of shared per block, so theoretical occupancy is 12% (one 256-thread block per SM).
- Each kernel reaches only 22–36% of the measured HBM copy limit. The top stall is `long_scoreboard` at 37–58%.
- cuFFT reaches 82–91% at 25% occupancy.

**H15** (hypothesis): too few bytes are in flight per SM. Each thread in the global→shared load loop (and the shared→global store loop) has about one 16 B access outstanding. Issuing K independent loads per thread before any shared store should raise HBM throughput at low occupancy.

## Task
1. Add `PlanOptions::load_batch` ∈ {1, 2, 4, 8}, default 1 (the current loop).
   - With K > 1, the pass-1 and pass-2 load loops read K elements into registers (unrolled, all loads issued first), then write them to shared.
   - The store loops do the same: K shared reads, then K global stores.
   - Make it a template parameter (dispatch like `radix_mode`), not a runtime branch inside the loop.
   - Report it in `describe()`.
2. Bench axis `--fft2-load-batch K`, label `,lb=K` (only when ≠ 1), with variants field `lb=`. Follow the T2d pattern.
3. Extend `fft2_test --variants` with `load_batch` ∈ {1, 4, 8} on the default plan, at all sizes. Output must be bit-identical across K (only the access order changes, not the arithmetic).

## Constraints
- Touch only `fft2/`, `bench/`, `scripts/`, `tests/`, and `docs/measurement.md`.
- Diff ≤ 300 lines, excluding tests.
- No performance claims. Report the ptxas register and spill numbers for K = 8 in the PR, or say that you could not build.

## Gate
- CPU: `make -C fft2 test-cpu`, `pytest tests -q`, and `shellcheck scripts/*.sh`.
- GPU (Claude, L4): sm_89 and sm_80 builds with zero warnings; `fft2_test --variants` exits 0; outputs for K = 1 and K = 8 are bit-identical.
- A100 A/B: `lb` ∈ {1, 4, 8} × the default plan; ncu at 2^20 and 2^24.
