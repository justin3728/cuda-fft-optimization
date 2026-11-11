# Codex Task T4a — fft2 tuning variants, round 1: index math + shared-memory padding

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create branch **`codex/t4a-fft2-variants`** from `codex/t2-two-pass-v1` (PR #2, not merged yet). Open a draft PR **targeting `codex/t2-two-pass-v1`**.

---

## Context
Read `CLAUDE.md`, `docs/plan.md` §4–5, `docs/optimization-log.md` (L001, L002), `fft2/README.md`. fft2 v1 is correct on L4 (28/28) and structurally 2-pass, but reached only 41–47 % of the copy limit there. We cannot measure on A100 yet, so this task prepares **switchable variants** of the candidate fixes; Claude will A/B them in one A100 allocation with ncu and only then decide which become default. These are hypotheses, not optimizations, until measured.

Candidate causes (from reading `fft2/fft2.cu`):
- **H9**: inner loops in `block_fft`, the pass-1 load/store and pass-2 load/store use `size_t` `/` and `%` by runtime values (`width`, `quarter`, `n2`, `cross_base`). 64-bit integer division is a long instruction sequence on GPUs. All divisors are powers of two → shift/mask with 32-bit indices (per-block element counts fit in 32 bits; only the global base offset needs 64 bits).
- **H10**: `shared_index(element, lane, lanes)` = `element * lanes + lane` with `padding == 0`; with lanes a power of two, butterfly access at stride `quarter*lanes` hits the same banks (FP64 = 2 banks per element). The padding hook exists but is unused.

## Hard constraints
1. Only touch `fft2/` (code, tests, reference, README). No other directory.
2. Default behaviour (`PlanOptions{}`) must stay **bit-identical** to v1 output in this task; variants are opt-in via new `PlanOptions` fields, e.g. `int index_mode = 0 /*0=v1 size_t div, 1=u32 shift/mask*/; int smem_padding = 0 /*elements per lane-row*/;`. Add them to `describe()`.
3. Implement variants with templates/compile-time specialisation so the v1 path has no extra runtime branching inside hot loops (dispatch once per launch).
4. Every variant must pass the same correctness tests as v1. Extend `fft2_test` with a `--variants` mode (or default extra configs) that runs the full config list for each of: `index_mode∈{0,1}` × `smem_padding∈{0,1,2}` where the shared-memory budget allows; print one line per config and a summary; exit non-zero on any failure. Keep total GPU runtime of `fft2_test` under ~3 min on an L4.
5. Update `fft2/reference/two_pass_model.py` so `shared_index` / `shared_bytes` with padding are modelled and tested on CPU (including that padded shared bytes still fit the opt-in limit, and that tile selection shrinks lanes when padding makes it exceed).
6. Commit and push after each item. No performance claims anywhere; README lists H9/H10 as hypotheses with the ncu metrics that would confirm them (`smsp__inst_executed` / `sass__inst_executed_per_opcode` for IMAD/integer-division sequences, `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld/st.sum`).

## Gate
CPU: `make -C fft2 test-cpu`, `make -C fft2 CUDA_ARCH=sm_80` and `sm_89` with zero warnings.
GPU (Claude): `make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test --variants` exit 0 on L4.

## Acceptance criteria
- [ ] Two new opt-in variant axes, v1 default unchanged, CPU model + tests for padding, GPU test mode covering all variants.
- [ ] `fft2/README.md` section "Tuning variants" (what each option does, expected effect = hypothesis, how to select it).
- [ ] PR description: list exactly what Claude must measure on A100 to accept/reject H9 and H10.
