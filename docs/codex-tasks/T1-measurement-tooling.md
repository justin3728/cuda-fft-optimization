# Codex Task T1 — Measurement tooling (no algorithm changes)

> Paste everything below the line into Codex. Repo: `justin3728/cuda-fft-optimization`.
> Read `docs/plan.md` first; it is the source of truth for project state.

---

## Context

This repo is a double-precision (FP64, complex-to-complex, forward) CUDA FFT. We are about to rebuild it into a 2-pass architecture aimed at the A100's memory-bandwidth limit. Before touching the algorithm we need measurement tooling that can answer, per kernel: **"how close is this to the measured HBM / L2 bandwidth limit of this GPU, and why not closer?"**

You do **not** have a GPU. The repo owner runs everything you write on a rented **NVIDIA A100** (Linux, CUDA 12.x, Nsight Compute installed) and commits the outputs back. So your code must be correct by construction, fail loudly with clear messages, and be runnable with one command.

## Hard constraints

1. **Do not change any algorithm or numeric output.** Do not modify `fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`, or anything under the existing `results/` files. The existing `make` default target must still build exactly as before.
2. The legacy implementation is used only through its public API (`fft_plan_cuda_1d` / `fft_execute_plan_cuda_async` / `fft_destroy_plan_cuda`) via an adapter.
3. Never fabricate or "example" performance numbers in docs, READMEs or PR text. Anything not run on a GPU is stated as unverified.
4. New C++/CUDA: C++17, `nvcc`, default `CUDA_ARCH=sm_80` for the new targets. Use `size_t` for element counts (N×batch reaches 2^25+).
5. All new outputs go to `results/<tag>/…` (tag provided at run time). Nothing writes into the repo root or into existing `results/*` files.

## Known facts about the legacy code (from `docs/plan.md` §4)

- Legacy supports only power-of-two **N ≤ 2^20** (shared array and twiddle table are 1024 points). For N > 2^20 the legacy backend must report `unsupported`, never run.
- Legacy batch is a host-side loop inside `fft_execute_plan_cuda_async`; that *is* the baseline behaviour, keep it.
- `fft_plan_cuda_1d` copies host input → host out → device at plan time; the adapter must account for that (plan with a host buffer, then overwrite `plan.out_device` with the test input via D2D before each timed run).
- The old `benchmark.cpp` times one execution per event pair right after an H2D copy; we are replacing that methodology in the new harness (not editing the old file).

## Deliverables

### Directory layout (target)

```
bench/
  common/            timing, L2 flush, error metrics, CSV writer, NVTX helpers
  backends/          backend interface + legacy, cufft, vkfft adapters
  fft_bench.cu       the sweep / profile driver
tools/
  bwtest.cu          bandwidth test
third_party/VkFFT    git submodule, pinned to a release tag
scripts/
  collect_env.sh
  run_bwtest.sh
  run_sweep.sh
  run_ncu.sh
  export_vkfft_kernels.sh
  run_t1_all.sh      one-command runner (calls everything above)
  analysis/          python: derive metrics, plots, ncu summary
tests/               pytest tests + fixtures for all python analysis code
```

Adjust names if you have a good reason; document the final layout in `docs/measurement.md`.

### Backend interface (will host the future new implementation)

Something equivalent to:

```cpp
struct FftBackend {
  virtual std::string name() const = 0;                       // "legacy" | "cufft" | "vkfft"
  virtual bool supports(size_t n, int batch, std::string* why) const = 0;
  virtual void plan(size_t n, int batch) = 0;                  // allocations, twiddles; not timed
  virtual cuDoubleComplex* buffer() = 0;                       // device buffer, n*batch, transformed in place
  virtual void execute(cudaStream_t s) = 0;                    // forward, in place, async, no host sync
  virtual void destroy() = 0;
};
```

All three backends transform **in place, forward, unnormalized**, contiguous batches (batch b starts at `b*n`). A later task adds our new implementation as a fourth backend, so keep the registry trivial to extend.

- **cufft**: `cufftPlanMany` Z2Z, `cufftSetStream`, `CUFFT_FORWARD`. Record the cuFFT version.
- **vkfft**: CUDA backend (`VKFFT_BACKEND=1`, NVRTC + driver API, link `-lcuda -lnvrtc`; link `libcuda` from `stubs/` if the driver is absent at build time). `doublePrecision = 1`, `numberBatches = batch`, single stream. Verify the forward sign convention matches cuFFT (the correctness check below will catch it on GPU; also document the choice in code). Pin VkFFT to its latest release tag as a git submodule; record the commit hash in env output.
- **legacy**: adapter around the existing API as described above. `supports()` returns false for N > 2^20 or non-power-of-two.

### (a) Bandwidth test — `tools/bwtest.cu`, `scripts/run_bwtest.sh`

Produce measured upper bounds; no spec-sheet numbers are used as "the limit".

1. **HBM peak**: buffers ≥ 2 GiB (≫ 40 MB L2). Kernels: read-only (with a result sink so it cannot be optimized out), write-only, copy (read+write). 16-byte vector accesses (`double2`), grid-stride loops. Sweep a small grid of launch configs (blocks per SM × threads per block) and report the best config and its bandwidth, plus `cudaMemcpy` D2D. Report GB/s as 10^9 bytes/s, counting read + write bytes.
2. **L2 curve**: working-set sweep from 1 MiB to 512 MiB (log-spaced; must include 8, 16, 20, 24, 32, 40, 48, 64, 96, 128 MiB). For each size, repeatedly read (and separately copy within) the same buffer many times while hot; report effective bandwidth. The curve must show the L2 plateau and the drop to HBM. Run with enough iterations that each data point takes ≥ 50 ms total.
3. **FFT-shaped one-pass floor**: for every (N, batch) config used by the sweep (see (c)), time an **in-place** element-wise copy (read and write `N*batch` complex doubles) and an out-of-place copy, in both `hot` and `cold` modes using the exact same timing code as the sweep. This gives `t_pass(N,batch)`, the time of one ideal memory pass at that exact size — the floor that the analysis divides by.
4. Also print theoretical DRAM bandwidth from device attributes if the attributes are available (mark NA otherwise) — for reference only.

Outputs: `results/<tag>/bandwidth/hbm.csv`, `l2_curve.csv`, `pass_floor.csv`, and `limits.json` with at least `{ "hbm_read_GBs", "hbm_copy_GBs", "hbm_write_GBs", "l2_read_GBs_plateau", "l2_copy_GBs_plateau", "l2_plateau_range_MiB" }` (plateau = median of points clearly inside L2; document the rule).

### (b) Nsight Compute — `scripts/run_ncu.sh`, `scripts/analysis/ncu_summary.py`

1. `fft_bench --profile` mode: for each requested config, plan, warm up, then execute **once** inside an NVTX range named `prof/<impl>/N<n>/b<batch>`. `run_ncu.sh` uses NVTX filtering so that exactly that execution's kernels are captured (VkFFT launches through the driver API; make sure those kernels are captured too).
2. Default profiled configs (overridable): N ∈ {2^16, 2^20, 2^22, 2^24} × {batch 1, batched-total-2^25}, for every supported impl. Also profile the bwtest copy kernels at one HBM-sized and one L2-sized working set so ncu itself confirms where traffic is served.
3. ncu settings: `--set full`, `--cache-control all`, `--clock-control none` as primary run. A second run for N=2^20 batch 1 only with `--cache-control none` (to see L2 reuse between kernels). Record the exact ncu command lines and ncu version in the output.
4. Export `.ncu-rep` and a raw CSV (`ncu --import … --page raw --csv`). If the total `.ncu-rep` size > 100 MB, keep only the N=2^20 and N=2^24 batch-1 reports in `results/` and print where the rest are.
5. Detect the counter-permission error (`ERR_NVGPUCTRPERM`) and print an actionable message (what to run with sudo / the driver module option), exit non-zero.
6. `ncu_summary.py` reads raw CSVs + `limits.json` and writes, per config, a per-kernel table (CSV + Markdown) with:
   impl, config, kernel (short demangled name), grid, block, registers/thread, static+dynamic smem, duration (µs), % of config total time, DRAM read bytes, DRAM write bytes, L2 (lts) bytes, achieved DRAM GB/s, **% of measured HBM copy limit**, achieved L2 GB/s, **% of measured L2 limit**, theoretical and achieved occupancy, shared-memory bank conflicts (ld/st), FP64 pipe utilization, top-3 warp stall reasons.
   Plus a per-config footer: total time, total DRAM bytes, "DRAM bytes / (2×16×N×batch)" (= number of effective memory passes).
   Suggested metric names (verify with `ncu --query-metrics` / section names for sm_80; if a metric is missing, emit NA and a warning instead of crashing): `gpu__time_duration.sum`, `dram__bytes_read.sum`, `dram__bytes_write.sum`, `lts__t_bytes.sum`, `sm__warps_active.avg.pct_of_peak_sustained_active`, `sm__maximum_warps_per_active_cycle_pct`, `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum`, `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_st.sum`, `sm__pipe_fp64_cycles_active.avg.pct_of_peak_sustained_active`, `launch__registers_per_thread`, `launch__grid_size`, `launch__block_size`, warp-state stall metrics from the WarpStateStats section.

### (c) Benchmark sweep — `bench/fft_bench.cu`, `scripts/run_sweep.sh`, `scripts/analysis/`

1. Configs: N = 2^16 … 2^24 (every power of two) × batch modes:
   - `b1`: batch = 1
   - `b8`: batch = 8
   - `t25`: batch = 2^25 / N (fixed 512 MiB of data)
   All configurable by CLI.
2. Impls: `legacy`, `cufft`, `vkfft` (selectable). Unsupported or failing configs produce a row with `status=unsupported|error` and a reason; the sweep continues (including after OOM).
3. Timing modes, both reported:
   - `hot`: warm up, then one event pair around K back-to-back executions (default K = 20; assert K ≤ 280 / log10(N) so values can't overflow FP64), time = elapsed / K. Repeat R trials (default 15), restoring the input with a D2D copy between trials (outside timing).
   - `cold`: before each single timed execution, run an L2-flush kernel that writes a buffer ≥ 2× L2 size (query L2 size from device attributes); event pair around one execution; R trials.
   Report median, min, p10, p90 per (impl, N, batch_mode, mode).
4. Correctness (every row, run once, outside timing): out-of-place cuFFT result on the same input is the reference. Report relative L2 error `‖x−ref‖₂/‖ref‖₂` and max abs error. Default pass threshold rel L2 ≤ 1e-12; `status=wrong` if violated. Input: deterministic seeded uniform [-1,1] for re and im. Additionally, for N ≤ 2^20 batch 1, an optional `--verify-fftw` cross-checks cuFFT itself against FFTW (`FFTW_ESTIMATE`, double).
5. Raw CSV columns (exact names, one row per impl×N×batch_mode×timing mode):
   `impl,N,log2N,batch,batch_mode,timing_mode,trials,iters_per_trial,time_ms_median,time_ms_min,time_ms_p10,time_ms_p90,rel_l2_err,max_abs_err,status,note`
6. `scripts/analysis/derive.py` joins the raw CSV with `pass_floor.csv` and adds:
   `gflops = 5*N*log2N*batch / t`, `bytes_one_pass = 32*N*batch`, `eff_bw_one_pass_GBs`, `pass_equiv = t / t_pass(N,batch,mode)` (in-place floor), `pct_of_cufft = t_cufft / t * 100`.
7. `scripts/analysis/plot_sweep.py` produces, per batch_mode and timing mode: (i) time vs N (log-log) for all impls with dashed lines for the 1-pass and 2-pass floors; (ii) `pass_equiv` vs N; (iii) % of cuFFT vs N. PNGs into `results/<tag>/plots/` plus `results/<tag>/summary.md` with the tables. Follow a colorblind-safe palette and keep one color per impl across all plots.

### (d) VkFFT kernel export — `scripts/export_vkfft_kernels.sh`

For a given list of configs (default: N ∈ {2^16, 2^20, 2^22, 2^24}, batch 1 and `t25`), make VkFFT emit the CUDA source it generates (use VkFFT's own mechanism, e.g. its keep/print-shader-code configuration option) and write each kernel to `results/<tag>/vkfft_kernels/N<n>_b<batch>/kernel_<k>.cu`, in launch order, plus `manifest.json` per config: VkFFT version/commit, config fields used, kernel count, and for each kernel the grid/block/shared-memory size if obtainable (else NA). This needs a GPU (VkFFT initializes against a device); it runs inside `run_t1_all.sh`.

### One-command runner — `scripts/run_t1_all.sh`

```
scripts/run_t1_all.sh --tag a100_2026xxxx [--quick] [--skip-ncu] [--dry-run]
```
- Builds everything (`make -B tools bench CUDA_ARCH=sm_80` or equivalent), runs `collect_env.sh`, bwtest, sweep, VkFFT export, ncu, analysis, in that order; each stage logs to `results/<tag>/logs/<stage>.log`; a failing stage is reported in a final status table but does not stop the independent stages after it.
- `collect_env.sh` → `results/<tag>/env.txt`: `nvidia-smi -q` (GPU SKU, memory size, ECC, clocks, power limit, persistence mode), driver, `nvcc --version`, `ncu --version`, cuFFT version, VkFFT commit, git commit of this repo, whether clocks could be locked (try nothing destructive; just report).
- `--quick`: N ∈ {2^16, 2^20, 2^24}, b1 only, R=3, ncu only N=2^20 — target ≤ 5 minutes. Full run target ≤ 45 minutes on an A100; print elapsed time per stage.
- `--dry-run`: prints every command it would run, runs nothing, needs no GPU.
- At the end print the list of files to `git add`.

## Acceptance criteria

**You (Codex) must satisfy before opening the PR:**
- [ ] `git diff --stat` shows no changes to `fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`, or existing `results/*` files; `make` (default target) unchanged.
- [ ] `pytest tests/` passes. Tests cover `derive.py`, `plot_sweep.py` (runs on fixture CSVs and writes PNGs), and `ncu_summary.py` using a **realistic fixture** of `ncu --page raw --csv` output (include a missing-metric case → NA + warning, not a crash).
- [ ] `bash -n` passes for every script; `shellcheck` clean or each suppression justified in a comment.
- [ ] `scripts/run_t1_all.sh --tag test --dry-run` runs on a machine without a GPU and prints the full command plan.
- [ ] If `nvcc` is available in your environment, all new targets compile for `sm_80` with zero warnings from our code; if not available, say so explicitly in the PR.
- [ ] `docs/measurement.md` documents: layout, how to run, timing methodology (hot/cold, K, R, L2 flush), what each CSV column means, how `limits.json` plateaus are chosen, ncu settings and why (`--cache-control`, `--clock-control`).
- [ ] `docs/plan.md` task board: set T1 to "PR open" (do not edit other sections).
- [ ] PR description lists: what was verified (build/tests), what could **not** be verified without a GPU, and any assumptions about VkFFT/ncu APIs that the GPU run must confirm.

**Verified later on the A100 (by the owner + Claude; design for these to pass):**
- [ ] `run_t1_all.sh` full run completes in ≤ 45 min; every stage status OK.
- [ ] `limits.json` exists; HBM copy bandwidth is plausible (sanity: between 60% and 100% of the device's theoretical value) and L2 plateau > HBM.
- [ ] `l2_curve.csv` shows a visible transition between ~20 MiB and ~64 MiB.
- [ ] Sweep: every cuFFT and VkFFT row 2^16–2^24 is `ok`; legacy rows are `ok` for N ≤ 2^20 and `unsupported` above; all `ok` rows have rel L2 error ≤ 1e-12.
- [ ] Legacy hot-mode median at N=2^20 b1 is within the same order as the old `results/benchmark_results.csv` (≈0.18 ms) — sanity check that the adapter runs the same code, not a regression gate.
- [ ] ncu summary tables exist for every profiled config, for all three impls, with DRAM bytes and % of measured limits filled (no NA for core metrics).
- [ ] VkFFT kernel sources exported for every requested config, `manifest.json` kernel count matches the number of kernels ncu captured for that config.

## Out of scope

Any change to FFT algorithms or kernels; inverse transforms; non-power-of-two sizes; FP32; multi-GPU; README rewrite (only `docs/measurement.md` is new documentation).
