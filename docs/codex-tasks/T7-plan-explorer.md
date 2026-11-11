# Codex Task T7 — fft2 plan explorer (static resource & access-pattern model, CPU only)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t7-plan-explorer`** from `codex/t4a-fft2-variants`. Open a draft PR targeting `codex/t4a-fft2-variants`.

---

## Context
Read `CLAUDE.md`, `docs/plan.md` §4–5, `docs/optimization-log.md` (L002: the 2^24 b1 pass-1 C=1 degeneration on L4, the 128 KiB shared/block → 1 block/SM concern), `fft2/README.md`, `fft2/fft2.cu` (`choose_tile`, split policy). We want a tool that, **without a GPU**, tells us for every (N, batch, PlanOptions, GPU) what the plan will be and which configs are structurally suspicious, so that A100 ncu time is spent on the right configs and the README can explain design choices. Everything it outputs is a model/prediction and must be labelled as such.

## Hard constraints
1. Only add: `fft2/tools/plan_explorer.py`, `fft2/tools/gpus.json`, `fft2/tools/test_plan_explorer.py`, a section in `fft2/README.md`. Do not modify `fft2/fft2.cu`, `fft2/fft2.h`, `fft2/tests/`, `fft2/reference/` (another branch, T4b, is changing `fft2/fft2.cu` in parallel).
2. The split/tile policy must be imported from or mirrored from the existing reference model (`fft2/reference/two_pass_model.py`); add a test that the explorer's chosen N1/N2/C/R equals the reference for all N in 2^16..2^24, batch {1,8}, padding {0,1,2}.
3. Commit and push after each item.

## Deliverables
`python fft2/tools/plan_explorer.py --gpu a100_40gb|l4 [--n ...] [--batch ...] [--padding 0,1,2] [--csv out.csv] [--md out.md]`, per pass and config:
1. Plan: N1, N2, tile C/R, blocks per grid, shared bytes/block.
2. Occupancy model: blocks/SM limited by shared memory (use the per-SM and per-block opt-in limits in `gpus.json`: A100 164 KiB/SM, 163 KiB/block opt-in, L4 100 KiB/SM, 99 KiB/block — cite sources in the JSON), threads (256/block), and a `regs_per_thread` input (default 64, overridable; T4b will report real ptxas numbers); resulting warps/SM and waves = blocks / (SMs × blocks/SM), tail-wave efficiency.
3. Coalescing model: bytes per contiguous global segment for loads and stores of each pass (C·16, R·16, N2·16 …), sectors touched per request vs ideal; flag `C*16 < 32` or `R*16 < 32` as `sector_waste`.
4. Shared-memory bank model: for each butterfly stage of `block_fft` and the load/store loops, compute bank-conflict degree per warp request for FP64 (8-byte words, 32 banks, 64-bit accesses as 2 bank-phases — document the model you used), for padding 0/1/2. Output the max/avg conflict degree per pass. (This is the prediction that ncu `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_*` will confirm or refute.)
5. L2 fit: working set (input + workspace + output) vs L2 size; flag `fits_l2`.
6. A `--md` summary table with a "suspicious" column (e.g. `1 block/SM`, `sector_waste`, `bank conflict ≥4-way`, `tail wave < 50%`), and a header line: "Model prediction — not a measurement."

## Tests
Policy equivalence with the reference (above); hand-checked small cases for occupancy, waves, sector waste, and bank conflicts (include a worked example in a test docstring); CLI smoke test writing CSV/MD to a temp dir.

## Gate
`python -m pytest fft2/tools -q` and `python fft2/tools/plan_explorer.py --gpu a100_40gb --md /tmp/a100.md` (attach the output to the PR description).
