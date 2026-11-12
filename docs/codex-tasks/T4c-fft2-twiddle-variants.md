# Codex Task T4c — fft2 twiddle access variants (H12)

> Branch **`codex/t4c-fft2-twiddle`** from `main` (T4t and T4b merged, T2d bench axes on #13). PR to `main`. Effort high. Items 1–3 can start now; item 4 is a second round after #13 (T2d) merges and `main` is merged into the branch.

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, and `docs/optimization-log.md` L001 (legacy's top L4 stall was `tex_throttle` 59 % from `__ldg` twiddle reads). In `fft2/fft2.cu`, both block FFT paths (`LegacyFFT` and `RegisterFFT`) read butterfly twiddles from the global `roots` table via `read_twiddle` (`__ldg`). Pass 1 also reads the cross twiddle as `cross_high[q] * cross_low[r]`: two loads and one complex multiply per element.

**H12** (hypothesis): twiddle loads through L1/tex add LSU pressure. Two alternatives may cut it:
- stage the length-L `roots` table into shared memory once per block, which costs shared memory and may lower occupancy;
- read a single cross table of size N instead of the two-table product, which costs footprint.

A100 will measure the trade-off. This task only builds the options.

## Task
1. `PlanOptions::twiddle_mode`, which defaults to 0:
   - 0 = the current `__ldg` table;
   - 1 = the block copies `roots` into shared memory before its first stage, and both FFT paths read it from there.

   Include the extra bytes in `shared_bytes` and in tile selection for both tile policies, and in the NumPy reference model. Add the mode to `describe()`.
2. `PlanOptions::cross_mode`, which defaults to 0:
   - 0 = the current two-table product;
   - 1 = one precomputed table of N entries, read once per element.

   Add the mode and the table bytes to `describe()`.
3. Extend `fft2_test --variants` with these axes on top of `radix_mode` ∈ {0,2} and `tile_policy` ∈ {0,1} only. Do not take the full cross product, and keep L4 runtime under about 6 minutes. Max rel L2 vs reference must stay ≤ 1e-14.
4. Bench axes, following the T2d pattern exactly:
   - add `--fft2-twiddle-mode` and `--fft2-cross-mode`;
   - label suffixes `,tw=M` and `,cx=M`, only when nonzero, after `rx` and before `oop`;
   - add matching `t1_fft2_name` and variants-file fields, with tests.

## Constraints
- Touch only `fft2/`, `bench/`, `scripts/`, `tests/`, and `docs/measurement.md`.
- Default output must be bit-identical to the current one.
- Diff ≤ 600 lines, excluding tests.
- No recurrence-based twiddles in this task; mention in the PR if you think they are worth a follow-up.
- No performance claims. Put the ptxas register and spill numbers in the PR description if you can build; otherwise say that you couldn't.

## Gate
- CPU: `make -C fft2 test-cpu`, `pytest tests -q`, `shellcheck scripts/*.sh`.
- GPU (Claude, L4):
  - sm_89 and sm_80 builds with zero warnings;
  - `fft2/fft2_test --variants` exits 0;
  - a 2-variant sweep at 2^20 b1 (`tw=1 cx=1`) where every row is ok and the labels match.
