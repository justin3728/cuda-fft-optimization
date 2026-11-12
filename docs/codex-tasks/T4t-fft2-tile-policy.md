# Codex Task T4t — fft2 `tile_policy`: occupancy-aware automatic tile size (H13)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t4t-tile-policy`** from `main`. Open a PR targeting `main`.

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, and `fft2/README.md`. In `docs/optimization-log.md`, read L005 (the H13 tile sweep table).

On A100, the current automatic tile picks the largest tile that fits (`choose_tile` in `fft2/fft2.cu`). This lands at 1 block/SM. L005 measured explicit tiles C = R = k. The best k is the **largest k whose shared memory per block is ≤ 32 KiB, with k ≥ 2**:

| L | best k | smem/block |
|---|---|---|
| 256 (2^16) | 4–8 | 16–32 KiB |
| 512 (2^18) | 4 | 32 KiB |
| 1024 (2^20) | 2 | 32 KiB |
| 2048 (2^22) | 2 | 64 KiB, because k = 1 breaks coalescing |

## Task
1. Add `PlanOptions::tile_policy`:
   - `0` = current behavior, and stays the default.
   - `1` = for each pass, choose the largest `lanes` (power of two, ≤ the other dimension) with `shared_bytes(length, lanes, padding) ≤ 32 KiB`. Use `lanes = 2` if no such tile exists, and fall back to policy 0's error path if 2 does not fit.
   - An explicit `tile_cols` or `tile_rows` still overrides the policy.
2. Add `tile_policy`, plus each pass's `lanes` and `smem_bytes`, to `describe()`.
3. CPU test: a table-driven test of the policy-1 choice for L = 2^8..2^12. These are host-only functions; expose them in a detail header if needed.
4. Add `tile_policy ∈ {0, 1}` to `fft2_test --variants`.

## Constraints
- Only touch `fft2/`. Numeric output must be bit-identical for every policy, because the tile only changes how many FFTs one block handles.
- Diff ≤ 250 lines, excluding tests.
- No performance claims. Follow the Coding principles in `CLAUDE.md`.

## Gate
- CPU: `make -C fft2 test-cpu`; sm_80 and sm_89 builds with zero warnings.
- GPU (Claude, L4): `fft2/fft2_test --variants` exits 0. Then A100 A/B: policy 0 vs 1 for b1 and batched. Make policy 1 the default only if A100 confirms it.
