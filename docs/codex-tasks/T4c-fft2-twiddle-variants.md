# Codex Task T4c — fft2 tuning variants, round 3: twiddle access

> Paste everything below the line into Codex **only after T4b has pushed at least its kernel commit** (it builds on it). Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t4c-fft2-twiddle`** from `codex/t4b-fft2-radix`. Open a draft PR targeting `codex/t4b-fft2-radix`.

---

## Context
Read `CLAUDE.md`, `docs/optimization-log.md` (L001: legacy's top stall on L4 was `tex_throttle` 59 % from `__ldg` twiddle reads), `fft2/README.md` "Tuning variants". fft2 reads every butterfly twiddle (`roots`) and the pass-1 cross twiddle (`cross_high[e / base] * cross_low[e % base]`, two loads + one complex multiply per element) from global memory via `__ldg`.

**H12** (hypothesis): twiddle loads through the texture/L1 path add LSU/L1 pressure; staging the length-L `roots` table in shared memory once per block (≤ L/2·16 B = 32 KiB at L=4096) or computing intra-stage twiddles by recurrence reduces `tex_throttle`/`lg_throttle` stalls. Shared-memory cost may reduce blocks/SM — that trade-off is exactly what A100 must measure.

## Hard constraints
1. Only touch `fft2/` (but **not** `fft2/tools/`, which another branch owns). Default output unchanged; new opt-in `PlanOptions::twiddle_mode`: 0 = v1 `__ldg` tables, 1 = `roots` staged in shared memory (account for it in `shared_bytes`/tile selection and the reference model), 2 = per-thread recurrence from one table load per stage for the radix-8/16 path only (document the error growth bound; rel L2 vs cuFFT must stay ≤ 1e-14). Add to `describe()`.
2. Cross twiddle: add `cross_mode`: 0 = v1 two-table product, 1 = single table of size N (memory cost N·16 B, report it in `describe()`), so A100 can show whether the extra multiply or the extra footprint matters.
3. CPU reference model updated for shared-memory accounting and recurrence accuracy (numpy test of max error vs exact over all L).
4. Extend `fft2_test --variants` with the new axes on top of the best-guess T4a/T4b defaults only (do not take the full cross product; keep L4 runtime < ~6 min).
5. Commit and push after each item. No performance claims; ptxas register/spill numbers in the PR description.

## Gate
CPU: `make -C fft2 test-cpu`, sm_80/sm_89 builds zero warnings. GPU (Claude): `fft2/fft2_test --variants` exit 0 on L4, then A/B on A100.
