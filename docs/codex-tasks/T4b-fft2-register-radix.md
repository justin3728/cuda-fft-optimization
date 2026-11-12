# Codex Task T4b — fft2 register-level radix-8/16 sub-FFTs (H11)

> Paste everything below the line into Codex **after T4t is merged into main**. Both tasks edit `fft2/fft2.cu`.
> Create branch **`codex/t4b-fft2-radix`** from `main`. Open a PR targeting `main`.
> (Revised 2026-11-12 after L005. The tile_policy part of the old addendum moved to T4t, with a rule the A100 data supports.)

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, `docs/plan.md` §5, and `fft2/README.md`. In `docs/optimization-log.md`, read L005.

On A100 at 2^24 b1, fft2 v1 takes 3203 µs, against 1260 µs for cuFFT. Each kernel reaches only 22–28% of the measured HBM limit. Raising occupancy from 12.5% to 25% did not help, while cuFFT reaches about 88% at the same 25%. So the bottleneck is how `block_fft` works:
- it runs log2(L)/2 radix-4 stages;
- every stage is a full shared-memory round trip plus a block barrier;
- L = 1024 needs 5 stages.

The standard fix:
- each thread loads R ∈ {8, 16} elements into registers;
- it does a radix-R butterfly in registers, with internal twiddles as compile-time constants;
- it applies the inter-stage twiddles;
- it exchanges through shared memory only between radix-R stages.

With this, L = 1024 needs 3 exchanges.

**H11:** fewer shared round trips and barriers raise the achieved bandwidth of both passes, most of all at 2^24.

## Task
1. Add `PlanOptions::radix_mode` and report it in `describe()`:
   - `0` = v1, and stays the default;
   - `1` = register radix-8;
   - `2` = register radix-16.

   A mixed last stage is allowed. The host computes the stage plan for L = 2^8..2^12 and passes it as template parameters.
2. Keep data in registers between stages. Size the shared buffer for **one exchange** and reuse it across stages.
3. Twiddles:
   - inter-stage: from the existing tables, with no runtime trig;
   - radix-8/16 internal: `constexpr`.
   - Accuracy: rel L2 vs cuFFT ≤ 1e-14; v1 reaches about 6e-16.
4. CPU reference: add the staged algorithm to `fft2/reference/two_pass_model.py`, including the exact element → thread → shared index maps the CUDA code uses. Test it against `numpy.fft` for every L and stage plan.
5. Add `radix_mode ∈ {1, 2}` to `fft2_test --variants`, crossed with `tile_policy ∈ {0, 1}`. Keep the L4 runtime under about 5 minutes.
6. In the PR description, report the per-kernel registers and spills from `nvcc -Xptxas -v` for sm_80.

## Constraints
- Only touch `fft2/`. Output for the default options stays identical to v1.
- Diff ≤ 600 lines, excluding tests and the README. If radix-16 would exceed that, deliver radix-8 only and say so in the PR.
- Commit and push after each item.
- No performance claims. Follow the Coding principles in `CLAUDE.md`.

## Gate
- CPU: `make -C fft2 test-cpu`, including the new staged-model tests; sm_80 and sm_89 builds with zero warnings.
- GPU (Claude): on L4, `fft2/fft2_test --variants` exits 0. Then an A100 A/B together with the T4t and T2c variants.
