# Codex Task T4b — fft2 tuning variants, round 2: register-level radix-8/16 sub-FFTs

> Paste everything below the line into Codex **after T4a is pushed** (it builds on it). Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t4b-fft2-radix`** from `codex/t4a-fft2-variants`. Open a draft PR targeting `codex/t4a-fft2-variants`.

---

## Context
Read `CLAUDE.md`, `docs/plan.md` §5, `fft2/README.md` (incl. T4a's "Tuning variants"). `block_fft` currently does log2(L)/2 radix-4 stages, each a full shared-memory round trip plus a block barrier (e.g. L=1024 → 5 stages, 5 barriers, ~10 shared reads+writes per element). The legacy kernel showed `barrier` and shared bank conflicts as major stalls on L4 (L001). The standard fix (VkFFT, cuFFT-style) is: each thread loads R ∈ {8, 16} elements into registers, does a radix-R butterfly in registers (with internal twiddles as compile-time constants), applies inter-stage twiddles, and exchanges through shared memory only between radix-R stages → for L=1024 with R=16/16/4 or 8/8/16: 3 exchanges instead of 5.

**H11** (hypothesis): fewer shared round trips and barriers raise achieved bandwidth of both passes; register pressure must stay ≤ ~128 regs/thread to keep ≥ 2 blocks/SM where shared memory allows.

## Hard constraints
1. Only touch `fft2/`. Default (`PlanOptions{}`) output stays identical to v1; the new path is opt-in via `PlanOptions::radix_mode` (0 = v1 radix-4 shared, 1 = register radix-8, 2 = register radix-16; mixed last stage allowed). Add to `describe()`.
2. Stage plan (which radices for a given log2 L, L = 2^8..2^12) computed on the host and passed as template/kernel parameters; document the plan table in the README.
3. Twiddles: inter-stage twiddles from the existing precomputed tables (no runtime trig); radix-8/16 internal constants as `constexpr` (e.g. √2/2) — keep FP64 accuracy (rel L2 vs cuFFT must stay ≤ 1e-14 in the test; v1 achieves ~6e-16).
4. CPU reference: add the same staged algorithm to `two_pass_model.py` (numpy) and test it against `numpy.fft` for every L and stage plan, including the exact element→thread→shared index maps the CUDA code uses (this is how we catch indexing bugs without a GPU).
5. Extend `fft2_test --variants` with `radix_mode ∈ {1,2}` (× T4a's best-guess defaults `index_mode=1, smem_padding=1`, plus one combo with each T4a axis off). Keep total L4 runtime < ~5 min.
6. Report per-kernel register count and spill from `nvcc -Xptxas -v` for sm_80 in the PR description (compile-time facts, not performance claims). If any variant spills, say so.
7. Commit and push after each item. No performance claims.

## Gate
CPU: `make -C fft2 test-cpu` (incl. new staged-model tests), sm_80/sm_89 builds zero warnings.
GPU (Claude): `fft2/fft2_test --variants` exit 0 on L4; then A/B on A100 together with T4a variants.

## Acceptance criteria
- [ ] Opt-in register-radix path for both passes, CPU model + index-map tests, GPU variant tests.
- [ ] README "Tuning variants" extended (stage plans, register/shared budgets per L, ptxas numbers).
