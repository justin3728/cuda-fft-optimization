# Codex Task T4e — VkFFT-style compile-time, register-resident load/store (H15)

> Branch **`codex/t4e-fft2-register-io`** from `main`, **after T4d (#15) merges**. PR to `main`. Effort high.
> Rewritten 2026-11-13 from the VkFFT kernel study (L007). It replaces the earlier "load_batch K" draft.

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, and `docs/optimization-log.md` L006 and L007. Also read these generated VkFFT kernels as the **design reference** (do not copy code; take the structure):
- `results/ab_a100_20261112/vkfft_kernels/N1048576_b1/kernel_0.cu`: 256 threads, 128 KiB shared, 32 fully unrolled loads/thread straight into registers, 2 barriers.
- `results/ab_a100_20261112/vkfft_kernels/N16777216_b1/kernel_0.cu`: 16 loads into registers, radix-16 in registers before any shared access, one shared exchange, stores straight from registers.

**Finding (L007):** VkFFT runs at 12.5% occupancy at 2^20 and still matches cuFFT. The difference from fft2 is the access pattern, not occupancy:
- fft2 loads in a runtime-count loop (`fft2/fft2.cu` pass1/pass2 load loops), one element per iteration, into shared, so each thread has about one load in flight.
- Every register-radix stage then reads from shared, computes, writes back, and hits a barrier.
- L006 ncu at 2^24: top stall `long_scoreboard` 37–58%, 22–36% of HBM copy limit.

The legacy code is also faster when its length is a compile-time constant, which points the same way.

**H15** (hypothesis): with the FFT length and lanes known at compile time, each thread can issue all its E = L·lanes/256 global loads back to back. Fusing the first and last radix stages into the global load and store should raise HBM throughput at the same occupancy.

## Task (commit and push after each item)
1. **Compile-time shape.** Add `PlanOptions::io_mode` ∈ {0, 1, 2}, default 0 (current code, unchanged).
   - `io_mode ≥ 1` requires a register radix (resolved radix 1 or 2); otherwise throw.
   - Template the kernels on `Lanes` as well as `LogLength`, dispatching over the lanes values the tile policy can produce. Report `io_mode` and E per pass in `describe()`.
2. **`io_mode=1`, straight-line I/O.**
   - Each thread loads its E elements with a fully unrolled sequence: all E global loads issued before any shared store, index math hoisted.
   - It then writes them to shared. The store side mirrors this: E shared reads, then E global stores (pass 1 multiplies the cross twiddle in registers).
   - Keep the warp's addresses coalesced exactly as today: the lane is fastest within a row, and rows are contiguous in pass 2.
   - The FFT arithmetic is untouched, so output must be **bit-identical** to `io_mode=0` with the same radix.
3. **`io_mode=2`, fused first and last stage.**
   - Choose each thread's E loaded elements so they are the inputs of its first-stage radix-R butterfly(s), as VkFFT kernel_0 does. Run that stage in registers, then write to shared.
   - The last stage reads from shared, runs in registers, applies the cross twiddle (pass 1), and stores straight to global.
   - Middle stages stay as they are. This saves one shared round trip and one barrier per pass.
   - Output must match cuFFT (rel L2 ≤ 1e-12). Bit-identity is not required.
4. **Bench and tests.**
   - `--fft2-io-mode M`, label `,io=M` only when nonzero (after `cx`, before `oop`), and variants field `io=`, following the T2d/T4c pattern.
   - `fft2_test --variants`: `io_mode` ∈ {1, 2} on the default plan at every log2 from 16 to 24, a bit-identity check for io=1 vs io=0, and API errors for io≥1 with radix 0.

## Constraints
- Touch only `fft2/`, `bench/`, `scripts/`, `tests/`, and `docs/measurement.md`.
- Diff ≤ 450 lines, excluding tests. If item 3 does not fit, stop after item 2 and say so.
- No performance claims. Report ptxas registers and spills for the largest E (L=4096, lanes=2, E=32) in the PR, or say that you could not build.

## Gate
- CPU: `make -C fft2 test-cpu`, `pytest tests -q`, and `shellcheck scripts/*.sh`.
- GPU (Claude, L4):
  - sm_89 and sm_80 builds, zero warnings, 0 spills;
  - `fft2_test --variants` exits 0;
  - a 3-row sweep at 2^20 b1 (`io=0/1/2` on the default plan), all ok.
- A100 A/B (Claude): `io` ∈ {0, 1, 2} × the default plan, all sizes; ncu at 2^20 and 2^24, next to VkFFT.
- Open question for the A/B: VkFFT switches to 3 kernels above 2^22 in FP64 (`swapTo3Stage4Step`). If io=2 still leaves 2^24 far from the HBM limit, a 3-pass 2^24 path is the fallback (a separate task).
