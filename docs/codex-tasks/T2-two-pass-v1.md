# Codex Task T2 — 2-pass FP64 FFT, version 1 (correctness first)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Create a new branch **from `main`** named `codex/t2-two-pass-v1` and open a separate PR. Another PR (#1, measurement tooling) is in progress on a different branch — do not touch its files.

---

## Context

Read `docs/plan.md` (§1 goals, §4 diagnosis, §5 target architecture) first. The legacy implementation does 5 global-memory passes at N=2^20 (3 transposes + 2 row FFTs). The goal of this project is a **2-pass** FP64 complex-to-complex forward FFT for N = 2^16 … 2^24 (power of two), batch ≥ 1, on an A100 (sm_80): every element is read from and written to global memory exactly twice per transform, with no standalone transpose.

This task is **version 1: correct, clean, and structurally 2-pass**. Performance tuning comes later, driven by Nsight Compute data from the A100, so prefer clear code with the right memory-access structure over micro-optimizations. You have no GPU; the owner and Claude will run the GPU tests.

## Hard constraints

1. All new code lives under a new top-level directory `fft2/`. Do not modify `fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`, the root `Makefile`, anything under `bench/`, `scripts/`, `tools/`, `results/`, `notebooks/`, or `docs/plan.md`.
2. CUDA C++17, `nvcc`, target `sm_80` (must also compile for `sm_89` so it can be smoke-tested on an L4). CUDA 13 toolkit: do not use removed `cudaDeviceProp` fields (`clockRate`, `memoryClockRate`, …).
3. Use `size_t` for element counts and offsets (N × batch reaches 2^25+).
4. No performance claims anywhere. Nothing is verified on GPU by you.
5. **Commit and push to `codex/t2-two-pass-v1` after each completed deliverable** (WIP commits are fine; open the PR as a draft early). Your usage window may end mid-task; unpushed work cannot be reviewed or resumed.

## Gate command (run on GPU by Claude)

```bash
make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test        # Colab L4 first (correctness)
make -C fft2 CUDA_ARCH=sm_80 && fft2/fft2_test        # then A100
```
Exit code 0 = pass. Make sure `fft2_test` prints one line per config and a final summary line, so a failure is diagnosable from the log alone.

## Mathematical decomposition (use exactly this; it is what the reference model checks)

For N = N1 · N2 (both powers of two), input index `n = N2·n1 + n2` and output index `k = k1 + N1·k2`, with n1, k1 ∈ [0, N1), n2, k2 ∈ [0, N2), and W_M = exp(−2πi/M):

```
X[k1 + N1·k2] = Σ_{n2} W_N2^{n2·k2} · ( W_N^{n2·k1} · Σ_{n1} x[N2·n1 + n2] · W_N1^{n1·k1} )
```

- **Pass 1** (per column n2): length-N1 FFT over the strided column `x[N2·n1 + n2]` (stride N2), multiply output k1 by the cross twiddle `W_N^{n2·k1}`, write `Y[N2·k1 + n2]` into a workspace buffer. A thread block processes a tile of **C consecutive columns** so that global loads/stores of one row of the tile are contiguous (C·16 bytes ≥ 32 bytes, i.e. C ≥ 2; prefer larger when shared memory allows).
- **Pass 2** (per row k1): length-N2 FFT over the contiguous row `Y[N2·k1 + n2]`, write `X[k1 + N1·k2]` to the output. Output is strided by N1, so a block processes **R consecutive rows k1** and stages results in shared memory so that each store of a fixed k2 writes R consecutive elements (R·16 ≥ 32 bytes, i.e. R ≥ 2).
- Natural-order output; no separate transpose kernel; exactly two kernels per transform (both handle all batches via the grid — **no host loop over batch**).
- Split: choose N1, N2 ∈ [2^8, 2^12] with N1 = 2^⌊log2N/2⌋, N2 = N / N1 (so N2 ≥ N1). Make the split a plan parameter so tuning can change it later.

### Twiddles
- Within-pass FFT twiddles (W_N1, W_N2 powers): precomputed FP64 tables in global memory, read through the read-only path or staged in shared memory — your choice, documented.
- Cross twiddle W_N^{n2·k1}: **two-level table**, `W_N^a = W_N^{a_hi·B} · W_N^{a_lo}` with `a = a_hi·B + a_lo`, B = 2^⌈log2(N)/2⌉ (both tables O(√N) entries). Reduce `a = (n2·k1) mod N` with 64-bit arithmetic. Tables computed on the host in long double (or double with careful argument reduction: compute the angle from `a mod N` as `2π·a/N`, never from a large product), uploaded at plan time.

### In-block FFT
- Length up to 4096 complex doubles (64 KiB) per column/row. Each thread holds several elements in registers and performs radix-4 or radix-8 butterflies; exchanges between stages go through shared memory (Stockham or decimation in time — your choice, documented). Correctness first; keep shared-memory indexing simple to change later (padding hook).
- Shared memory: use dynamic shared memory and `cudaFuncSetAttribute(..., cudaFuncAttributeMaxDynamicSharedMemorySize, ...)` when a configuration needs more than 48 KiB. The plan must reject (clear error) any configuration that exceeds the device's opt-in limit (`cudaDevAttrMaxSharedMemoryPerBlockOptin`), and pick C / R so that A100 (163 KiB opt-in) and L4 (99 KiB) both work for every N in range — with C or R falling back to 2, or 1 only if unavoidable (document).

## API (`fft2/fft2.h`)

```cpp
namespace fft2 {
struct PlanOptions { int n1 = 0; int tile_cols = 0; int tile_rows = 0; }; // 0 = automatic
class Plan {
 public:
  Plan(size_t n, int batch, PlanOptions opts = {});  // validates, allocates workspace + tables; no data movement
  ~Plan();
  Plan(const Plan&) = delete; Plan& operator=(const Plan&) = delete;
  // Forward, unnormalized. in == out allowed (pass 1 consumes `in` fully before pass 2 writes `out`).
  void execute(const cuDoubleComplex* in, cuDoubleComplex* out, cudaStream_t stream) const;
  size_t n() const; int batch() const; int n1() const; int n2() const;
  size_t workspace_bytes() const;
  std::string describe() const;  // split, tile sizes, grid/block/smem per kernel
};
}
```
Errors: throw `std::runtime_error` with a clear message (no `exit()`).

## Deliverables

1. `fft2/fft2.h`, `fft2/fft2.cu` (plus internal headers as needed).
2. **`fft2/reference/two_pass_model.py`** — a NumPy model of *exactly* the decomposition above: same index maps, same pass structure, same two-level cross-twiddle table construction, same tile shapes (simulate the per-tile loads/stores so a wrong tile index would show up). Plus `fft2/reference/test_two_pass_model.py` (pytest) comparing against `numpy.fft.fft` for N = 2^4 … 2^20 (all powers, several N1 splits incl. N1 = N2 and N1 < N2, batch 1 and 3), rel L2 error ≤ 1e-13. Mark N ≥ 2^21 as a slow test (skipped by default, runnable with a flag). **You can and must run these tests.**
3. `fft2/tests/fft2_test.cu` — GPU correctness executable: for N = 2^16 … 2^24, batch ∈ {1, 3, 8} (skip combos that exceed a memory cap), random input, compares against cuFFT `CUFFT_Z2Z` forward, out-of-place and in-place (`in == out`), reports rel L2 error and max abs error per config, exits non-zero if any rel L2 error > 1e-12. Also a `--describe` flag printing `Plan::describe()` for every N.
4. `fft2/Makefile`: `make -C fft2 CUDA_ARCH=sm_80` builds `fft2_test`; `make -C fft2 test-cpu` runs the pytest model tests. Warnings as errors for our code (`-Xcompiler=-Wall,-Wextra`, `-Werror=all-warnings` if your nvcc supports it, else document).
5. `fft2/README.md`: the decomposition, data layout diagrams (text), tile shapes, twiddle scheme, shared-memory budget table per N for A100 and L4, and a "Known performance questions for the A100 run" list (e.g. bank conflicts in your exchange pattern, register count, occupancy) — questions, not answers.

## Acceptance criteria

**Before opening the PR (you):**
- [ ] `pytest fft2/reference` passes (non-slow set) and you include the output summary in the PR description.
- [ ] The CUDA kernels implement the same index maps as the Python model (state in the PR how you cross-checked them, e.g. shared helper formulas documented side by side).
- [ ] If `nvcc` is available, `fft2_test` compiles for `sm_80` and `sm_89` with zero warnings; if not, say so explicitly.
- [ ] `git diff --stat main` touches only `fft2/` (and `docs/codex-tasks/` is untouched).
- [ ] PR description lists assumptions the GPU run must confirm.

**On GPU (Claude/owner, Colab L4 then A100):**
- [ ] `fft2_test` passes every config (rel L2 ≤ 1e-12) on L4 and on A100.
- [ ] Exactly 2 kernel launches per `execute()` regardless of batch (verified with ncu/nsys).
- [ ] ncu shows DRAM/L2 traffic ≈ 2 passes for N where working set ≫ L2 (2^24 batch 1, 2^22 batch 8).

## Out of scope

Performance tuning, inverse transform, non-power-of-two N, N < 2^16 or > 2^24, FP32, integrating into `bench/` (done later in a small follow-up after PR #1 merges), README of the repo root.
