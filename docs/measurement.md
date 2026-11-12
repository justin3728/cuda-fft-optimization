# T1 measurement tooling

This tooling measures FP64 complex-to-complex, contiguous, forward, unnormalized
FFTs with four backends: legacy, cuFFT, VkFFT and fft2. Execution is in-place by
default; fft2 also supports an explicit out-of-place comparison. It does not
change the existing FFT implementation or its default build. The owner supplied a successful pre-fix L4 quick smoke run in
[`results/smoke_l4_20261111/`](../results/smoke_l4_20261111/). The review fixes
documented here and the fft2 integration require another GPU run; no new GPU
measurements accompany this round. A100 correctness, throughput and the full runtime target remain
**unverified**. Synthetic arithmetic fixtures and reconstructed raw-CSV unit
fixtures are identified as test inputs, rather than new performance results.

## Layout

| Path | Purpose |
| --- | --- |
| `bench/common/` | CUDA resource/error handling, CLI/config parsing, CSV/JSON escaping, vector memory kernels, seeded input, correctness metrics, shared event timing, L2 flush, NVTX |
| `bench/backends/` | Small backend interface/registry and public-API legacy, cuFFT, VkFFT, fft2 adapters |
| `bench/fft_bench.cu` | Sweep supervisor, isolated config workers, single-execution profiling, VkFFT export |
| `bench/Makefile.inc` | Optional C++17 measurement targets, included after the original Makefile rules |
| `tools/bwtest.cu` | HBM launch sweep, L2 curve, exact-size hot/cold pass floors, bandwidth profiling |
| `third_party/VkFFT` | Git submodule pinned to release `v1.3.4`, commit `066a17c17068c0f11c9298d848c2976c71fad1c1` |
| `scripts/common.sh` | Shared shell arguments, safe result tags, command printing |
| `scripts/collect_env.sh` | Read-only environment collection |
| `scripts/run_bwtest.sh`, `scripts/run_sweep.sh` | Bandwidth and FFT measurements |
| `scripts/export_vkfft_kernels.sh`, `scripts/run_ncu.sh` | Generated CUDA sources and per-launch profiler reports |
| `scripts/run_analysis.sh`, `scripts/analysis/` | Derived CSV, PNG plots, summary tables, counter selection and report retention |
| `scripts/run_t1_all.sh` | Build and run every stage, with logs, elapsed times and final status table |
| `scripts/run_fft2_variants.sh`, `scripts/fft2_variants_default.txt` | One-allocation variant sweeps/profiles with shared build, baselines and calibration |
| `tests/` | Python analysis tests, realistic ncu CSV format fixtures, CPU shell orchestration tests |

All generated run files and build products go beneath `results/<tag>/`. The
runner refuses an existing tag directory; standalone stages refuse their existing
output files. Use a new tag for a repeat run. Existing result files are never
used as destinations. Oversized ncu binary reports have the explicit retention
exception described below; all of their raw CSVs stay in the run directory.

## Prerequisites and commands

Run on Linux with a CUDA 12.x/13.x toolkit, a supported host C++17 compiler (GCC 9 or
newer), NVIDIA driver, cuFFT, NVRTC, CUDA driver development library/stubs,
NVTX3 headers, Nsight Compute, Bash, GNU Make, Git and Python 3.10+.
The updated project plan also targets Colab's CUDA 13.0 environment. The scripts
explicitly build `sm_80`, and bandwidth reference queries use device attributes
instead of the `cudaDeviceProp` clock fields removed in CUDA 13. The owner's
pre-fix L4 smoke run validated CUDA 13 compilation and VkFFT initialization;
the T2b harness compiles locally with CUDA 13.5 for sm_80 and sm_89 with zero warnings.
If the toolkit does not include `nvtx3/nvToolsExt.h`, install NVIDIA's NVTX3
headers on the compiler include path. Optional FFTW checks require double
precision FFTW headers/library (`libfftw3-dev` on Ubuntu).

```bash
git submodule update --init third_party/VkFFT
python3 -m pip install -r scripts/analysis/requirements.txt

# CPU-only full command plan: creates no files and requires no GPU/toolkit.
scripts/run_t1_all.sh --tag test --dry-run

# All stages, or a first short run; always use a fresh tag.
scripts/run_t1_all.sh --tag a100_20261111
scripts/run_t1_all.sh --tag a100_20261111_quick --quick
scripts/run_t1_all.sh --tag a100_20261111_no_ncu --skip-ncu
```

The quick run uses sweep/export exponents `16,20,24`, batch mode `b1`, and
`R=3`; its ncu FFT profiles use exponent `20` only. Bandwidth limit measurements
keep their required working-set sizes and minimum durations in quick mode.
The full sweep uses every exponent `16..24`, modes `b1,b8,t25`, `R=15`, `K=20`.
Targets are at most five minutes for quick and 45 minutes for full, **not
verified on the A100**. The full default ncu plan now has an upper bound of
352 captured kernel launches, including cache-policy comparisons and bandwidth
copies. Its dry-run prints the bound per config and in total. Replay cost still
depends on the installed ncu release and GPU host. The runner reports actual
elapsed seconds per stage in `stage_status.csv`.

The optional targets default to `sm_80` even though the unchanged legacy default
target defaults to `sm_61`. Explicit `CUDA_ARCH` overrides the new targets too.
They build beneath the provided tag and do not reuse the root legacy object.
The driver link uses the toolkit's `lib64/stubs` or
`targets/x86_64-linux/lib/stubs` when present; the stub directory is never added
to runtime rpath or `LD_LIBRARY_PATH`. Execution needs the real host driver.

```bash
make -B tools bench TAG=a100_manual CUDA_ARCH=sm_80
scripts/collect_env.sh --tag a100_manual
scripts/run_bwtest.sh --tag a100_manual --log2 16,20,24 --batch-modes b1 --trials 3
scripts/run_sweep.sh --tag a100_manual --log2 16,20,24 --batch-modes b1 --trials 3
scripts/export_vkfft_kernels.sh --tag a100_manual
scripts/run_ncu.sh --tag a100_manual
scripts/run_analysis.sh --tag a100_manual
```

Use the same `--log2`, `--batch-modes`, `--trials` and `--iters` for bandwidth
floors and the FFT sweep. Batch modes are `b<count>` or `t<log2-total>`; `t25`
means `batch=2^25/N`, or 512 MiB of complex doubles. Sizes must divide the fixed
total. Use `--impls legacy,cufft,vkfft,fft2` to select implementations (the default).
`--profile-log2` and `--profile-batch-modes` configure full-mode ncu/export
configs, defaulting to `16,20,22,24` and `b1,t25`. Quick export follows the quick
sweep sizes/modes, while quick profiling uses `--profile-log2` and batch one.
Equivalent batch labels share one generated-source export per actual N/batch;
ncu can still profile each label separately.
`--ncu-max-kernels` (default 50) controls legacy sampling and is rounded down to
complete batches. `--ncu-library-max-kernels` (default 12) is a safety guard for
cuFFT/VkFFT; reaching it is an error because a complete library execution cannot
then be inferred. Raise that guard when the installed library legitimately uses
more kernels. Both options propagate through `run_t1_all.sh`.
`PYTHON`, `NCU` and `CUDA_ARCH` can select installed tools/architecture. Direct
binary invocations support `--n`, explicit `--batch`, `--warmup`, `--threshold`
and `--help` in addition to the documented shell options. For explicit-batch
single-config runs, pass one `--batch-modes b<count>` label as well.

To cross-check cuFFT against FFTW, pass `--verify-fftw` to the runner; this builds
with `WITH_FFTW=1`. The check uses `FFTW_FORWARD`, double, `FFTW_ESTIMATE` only
for `N <= 2^20`, batch one. A binary built without FFTW reports an error when
this eligible check is requested.

## Backend contract and failure handling

`FftBackend` separates support checks, planning, the contiguous device buffer,
stream-based execution and destruction. Allocation, twiddles, library
initialization/JIT and copies are excluded from timed execution. Add a new
adapter through the three-line registry in `backend.hpp`.

* Legacy checks the power-of-two and `N <= 2^20` bounds **before planning**.
  It also rejects `N*batch > INT_MAX` because legacy uses signed integer offsets.
  It plans with a caller-owned host buffer through `fft_plan_cuda_1d`, then the
  harness restores `plan.out_device` by D2D before correctness/timing. Execution
  calls only `fft_execute_plan_cuda_async`; its host batch loop and scratch
  behavior remain intact. Destruction uses `fft_destroy_plan_cuda`.
* cuFFT uses `cufftPlanMany`, `CUFFT_Z2Z`, explicit contiguous distances/strides,
  `cufftSetStream` and `CUFFT_FORWARD`. A cached stream binding calls
  `cufftSetStream` only on the first warmup or a stream change, outside the
  same-stream timed execution loop. Its version is recorded in `env.txt`.
* VkFFT uses `VKFFT_BACKEND=1`, driver launches and NVRTC. Configuration sets
  `FFTdim=1`, `doublePrecision=1`, `numberBatches=batch`, one stream, one buffer,
  and `makeForwardPlanOnly=1`. `VkFFTAppend(...,-1,...)` selects the negative
  exponential forward convention, matching cuFFT. No normalization is enabled.
  With one stream VkFFT's pinned code does not use its multi-stream host sync.
  After initialization, a checked `cudaDeviceSynchronize()` completes setup
  issued on stream 0 before the nonblocking timing stream is used. Execution
  updates its stream pointer only when the stream changes.
* fft2 uses the unmodified `fft2::Plan` compiled directly from `fft2/fft2.cu`.
  Support requires power-of-two N in `2^16..2^24`, batch >= 1, and enough free
  device memory for its workspace, backend-owned data buffer(s), and up to
  256 KiB of twiddle tables. The plan also validates split, shared-memory and
  grid limits. Extra harness/reference allocations can still fail in a worker
  and are reported as errors. Execution calls `plan.execute(buf, buf, stream)`
  by default. `--fft2-out-of-place` allocates a distinct output buffer and
  correctness compares that output, while input restoration targets the input.
  Planning, allocation and table upload stay outside timing/NVTX.

Use `--impl fft2` (or `--impls fft2`) and `--fft2-n1 K --fft2-tile-cols C
--fft2-tile-rows R` in the binary or shell runners. Every tuning option defaults
to 0, selecting the plan's device-dependent automatic policy. Requested values
form the stable CSV/NVTX name, e.g. `fft2[n1=1024,c=8,r=4]`; out-of-place adds
`,oop=1` before the closing bracket. Auto is `fft2[n1=0,c=0,r=0]`. Resolved
N1/N2/C/R, launch dimensions, shared bytes and workspace bytes come from the
unaltered `plan.describe()` and are recorded in `impl_detail`. The requested
name stays consistent across sizes, including when auto resolves differently.

```bash
scripts/run_sweep.sh --tag fft2_manual --impl fft2 --log2 20 --batch-modes b1 \
  --fft2-n1 1024 --fft2-tile-cols 8 --fft2-tile-rows 4 --fft2-out-of-place
```

For out-of-place hot trials, the K executions read the same restored input
and overwrite the same output; in-place hot trials repeatedly transform their
buffer. Neither mode adds a timed copy or swaps the two pass kernels. The
measured in-place pass floor remains the common normalization for both modes;
the separate out-of-place floor is retained for traffic comparisons.

The sweep supervisor does not create a CUDA context. It fork/execs a new worker
for each implementation/config, captures its log, and collects two timing-mode
rows. This is necessary because the unchanged legacy API calls `exit()` on CUDA
errors. Worker exit, OOM and device launch faults produce error rows and do not
prevent later configs from being attempted. Worker logs live in
`sweep/config_logs/`; intermediate rows live in `sweep/rows/`.
Any `wrong`/`error` config makes the sweep exit nonzero after all configs run;
`unsupported` is an expected status. The one-command runner continues all later
independent stages, records failures and returns nonzero if any stage failed.

## Input, correctness and timing

The input generator uses a fixed seed `12345`, a stateless integer mixer per
element/component, and 53-bit uniform values in `[-1,1)`. Every implementation
sees the same data for a given config. All element/byte counts in new CUDA code
are `size_t`; library dimension/batch limits are checked at their boundaries.

For each implementation/config, one untimed execution is compared with an
**out-of-place** cuFFT result on the same original input. GPU block reductions
compute sum squared differences, reference energy, maximum complex magnitude
error and a nonfinite flag; the host combines block sums using `long double`.
Relative L2 is `sqrt(sum(abs(x-ref)^2) / sum(abs(ref)^2))`; maximum absolute error
is `max(abs(x-ref))`. A nonfinite result or relative error above the default
`1e-12` gives `status=wrong`. The correctness result applies to both timing-mode
rows. Optional FFTW reference-check errors are recorded in each row's note and
can also make that config wrong.

Both the FFT sweep and both copy floors call the **same** `time_trials` helper:

1. Three warmups by default, each preceded by input restoration. This warms code
   and scratch without accumulating FFT amplification across warmups.
2. **Hot:** restore the input by D2D outside timing, then record one CUDA event
   pair around `K=20` back-to-back in-place executions on the same nonblocking
   stream. Divide elapsed time by K. Repeat for `R=15` trials.
3. **Cold:** restore by D2D, launch a grid-stride **read** flush covering at least
   twice the queried `cudaDevAttrL2CacheSize`, then place one event pair around
   **one** execution. Restore, flush and events are ordered on the same stream;
   neither restore nor flush contributes to the measured interval. Repeat R
   times. The program fails clearly if L2 size cannot be determined.
   The flush source is initialized and primed once, with checked synchronization
   outside timing. Each flush uses `.cg` loads and a small per-block result sink;
   it evicts data without leaving a dirty 2×L2 write buffer that the timed kernel
   would have to write back. The sweep and both pass floors use this same helper.
4. Synchronize the end event and compute median, minimum, p10 and p90 over the
   per-execution samples. Percentiles use linear interpolation between sorted
   adjacent ranks, at `(R-1)*q`.

`K <= 280/log10(N)` is checked in release builds as well as asserted; excessive
K is an error. Hot mode is a repeated-execution workload: it includes library
and legacy host launch gaps visible between stream events. It does not imply
that every working set fits in L2. Cold timing measures a cold start for each
execution, and kernels later in that execution can reuse earlier kernels' data.

## Bandwidth limits and floors

HBM source/destination buffers are each at least 2 GiB. Read, write and copy
kernels use grid-stride loops and explicit 16-byte vector loads/stores
(`double2`), with PTX `.cg` cache operators to bypass L1. Read kernels reduce to
a small per-block device sink, preventing
dead-code elimination. Reported read bytes are payload only; sink writes and
reduction instructions are small overhead, not added payload. The in-place
floor uses observable vector loads/stores, so its identity assignment cannot
be optimized away.

The HBM search tries blocks-per-SM `{1,2,4,8}` and threads `{128,256,512}` for
each kernel, records every config and marks the best. D2D `cudaMemcpyAsync`
is measured separately. Each bandwidth point adaptively increases an event's
iteration count until its final timed interval is at least 50 ms; pilot samples
are discarded. GB/s means `bytes / seconds / 10^9`, with both read and write
bytes counted for copy. Measured kernel-copy bandwidth, rather than theoretical
DRAM bandwidth or the D2D API's result, is the HBM normalization limit.

The L2 curve samples total distinct working sets of
`1,2,4,8,16,20,24,32,40,48,64,96,128,256,512 MiB`. A read touches one buffer of
the specified size; a copy touches separate source and destination buffers of
half that size each. This keeps read/copy cache-capacity transitions comparable.
Each repeatedly accesses the same buffers after warmup, using that operation's
best HBM thread count, a block count capped to the kernel's resident occupancy,
and 64 memory passes inside each launch, for a final event
interval of at least 50 ms. Repetition amortizes host launch gaps and the read
sink reduction; `.cg` prevents an L1-resident result from being labeled L2.
The resident-grid cap prevents different launch waves from repeatedly reusing
small private slices and hiding the full working set's cache-capacity transition.
`in_plateau=1`
identifies the deliberately conservative rule:

**4 MiB <= sampled total distinct working set <= half the reported L2 size.**

For each operation the L2 limit is the median GB/s over those points.
`l2_plateau_range_MiB` stores their sampled minimum/maximum, and `l2_size_bytes`
and `l2_plateau_rule` make the choice auditable. No spec-sheet bandwidth is used
as a normalization limit. The rule selects resident points; the owner must
inspect the full curve and ncu traffic to confirm an actual plateau/transition.
The read sink adds a small footprint outside the labeled payload working set.
If there are no eligible resident points, the program errors rather than
inventing a plateau. The optional memory-clock/bus-width attribute calculation
`2*clock_kHz*1000*(bus_bits/8)/10^9` is labeled reference-only and is JSON null /
printed NA if unavailable.

For every sweep config, `pass_floor.csv` contains hot/cold **inplace** and
**outofplace** vector copies of `N*batch` complex doubles. Byte traffic is
`32*N*batch` for each copy kind. Launch dimensions use the best HBM copy config.
The in-place median at the same N, batch, batch label and timing mode is
`t_pass`; the analysis uses this measured floor even when it is L2-resident.
The out-of-place floor is retained for comparison and has two distinct touched
buffers.

## CSV and JSON fields

`sweep/raw.csv` has exactly these columns, in this order:

| Column | Meaning |
| --- | --- |
| `impl` | `legacy`, `cufft`, `vkfft`, or a requested fft2 variant such as `fft2[n1=0,c=0,r=0]` |
| `N`, `log2N` | Complex elements per transform and its base-two exponent |
| `batch`, `batch_mode` | Actual contiguous transform count and requested `b…`/`t…` label |
| `timing_mode` | `hot` or `cold` |
| `trials` | Number of event trials R |
| `iters_per_trial` | K in hot mode; one in cold mode |
| `time_ms_median`, `time_ms_min`, `time_ms_p10`, `time_ms_p90` | Per-execution time statistics, milliseconds |
| `rel_l2_err`, `max_abs_err` | One-execution correctness errors, outside timing |
| `status` | `ok`, `wrong`, `unsupported`, or `error` |
| `note` | Seed, optional FFTW results, or failure/unsupported reason and worker-log path |
| `impl_detail` | Appended column: resolved `fft2::Plan::describe()`; empty for other backends and plans that were not created |

Unmeasured values are `NA`. Incorrect results may have measured timing fields,
but do not contribute to derived metrics or plots. Nonfinite correctness
errors from a wrong result can be represented as `inf`, never accepted as ok.

`sweep/derived.csv` preserves raw columns and adds:

| Column | Definition (`time_ms_median = t_ms`) |
| --- | --- |
| `gflops` | `5*N*log2N*batch / (t_ms*10^6)` |
| `bytes_one_pass` | `32*N*batch`, read plus write complex-double bytes |
| `eff_bw_one_pass_GBs` | `bytes_one_pass / (t_ms*10^6)` |
| `t_pass_ms` | Same-config in-place floor median in milliseconds |
| `pass_equiv` | `t_ms/t_pass_ms` |
| `pct_of_cufft` | Same-config/same-mode `t_cufft/t_ms*100`; higher is faster |

Invalid/missing times or limits produce NA and warnings, never zeros. Duplicate
join keys are errors. Separate batch labels remain separate even when they
yield the same actual batch count.

`bandwidth/hbm.csv` identifies `kernel`, `buffer_bytes` (per large buffer),
`traffic_bytes` (per execution), `blocks_per_sm`, `threads`, `iterations`,
`total_ms` (the final interval), `time_ms` (per iteration), `GBs`, and `is_best`.
Launch columns for the D2D API row are placeholders, not its internal launch
parameters. `l2_curve.csv` adds `working_set_MiB` (sum of distinct data buffers),
`passes_per_launch` and `in_plateau`, without `is_best`. Its `iterations` counts
launches, `traffic_bytes` is per memory pass, and `time_ms` is total time divided
by launches and passes-per-launch. `pass_floor.csv` identifies N/batch/batch_mode/timing_mode,
`copy_kind`, trials/iterations, the four per-execution statistics,
`bytes_one_pass`, status and note. `limits.json` contains HBM read/copy/write
maxima, the D2D API comparison, L2 read/copy medians, plateau range/rule, reported
L2 size and optional reference theoretical DRAM bandwidth.

CSV fields are escaped, including variant names and plan descriptions containing
commas. Analysis still accepts older CSVs without `impl_detail`.

Plots in `plots/` use a fixed Okabe-Ito color for each backend, across
all batch/timing groups. fft2 uses purple; each requested variant is a separate
series with its own legend entry and marker/line style. For each group they show time versus N on log-log
axes, dashed measured 1-pass/2-pass floors, pass equivalents, and percent of
cuFFT. `summary.md` includes every row's status and errors, including unsupported
or failing configs, so missing curves do not hide failures.

## fft2 variants in one allocation

Run `scripts/run_fft2_variants.sh` once inside an already allocated GPU job. It
builds once, collects the environment, measures bandwidth/floors once, and runs
legacy/cuFFT/VkFFT baselines once. It then runs every selected fft2 variant in
sequence. `--ncu` enables profiling; the baseline job supplies the shared copy
calibration and variant jobs use `--skip-copy-profiles`. The script does not
allocate a GPU. An individual failed sweep/profile does not stop later variants,
and any failure makes the final exit code nonzero.

```bash
# Inspect the complete command list without files, a toolkit or a GPU.
scripts/run_fft2_variants.sh --tag fft2_ab \
  --variants scripts/fft2_variants_default.txt --ncu --dry-run

# Run in a single A100 allocation; omit --ncu for sweep-only comparisons.
scripts/run_fft2_variants.sh --tag fft2_ab \
  --variants scripts/fft2_variants_default.txt --ncu
```

Each nonblank variant line contains `n1=K c=C r=R`. `#` begins a comment, and
the final line may omit its newline. Optional `log2=20,21` selects sizes from
the intersection with CLI `--log2`; optional `oop=0|1` chooses buffer mode.
Without these fields a line uses all requested sizes and the CLI buffer mode
(in-place by default). For example:

```text
n1=0 c=0 r=0
log2=20 n1=1024 c=4 r=4
log2=20 n1=1024 c=8 r=8 oop=1
```

The default file includes the auto policy and six alternatives for each exponent
16..24: smaller tiles, alternate splits where valid, and out-of-place cases.
These are candidates based on `fft2/README.md`'s calculated shared-memory budgets,
not tuning results. Explicit defaults need at most 128 KiB per pass, fitting the
documented A100 163 KiB opt-in budget. Some exceed L4's 99 KiB budget: for L4,
use an auto-only file or reduce explicit tiles to fit the queried device limit.
The default auto line adapts to both devices. The whole file's syntax, dimensions
and duplicate configs are checked before commands execute; runtime plan creation
checks device-specific tile limits. No file contents are evaluated as shell code.

The runner accepts the common size/timing/profile options. The file owns N1/C/R
and the baseline set is fixed; choose a subset of file lines/sizes for shorter
jobs. Profiles use each line's intersection with `--profile-log2` and profile
batch modes. An empty profile intersection still permits a sweep.

All final artifacts are contained in `results/<tag>/`: `variants.csv` maps
requested configs to `variants/v001/`, etc.; `variants/baseline/` and each worker
retain raw CSVs, logs and profiler artifacts. Workers temporarily use unique
`<tag>.baseline`/`<tag>.v001` tags, then move into that tree. Binary paths point
to the shared `<tag>/build/`. `merge_variants.py` combines sweep rows and rebases
the ncu index paths before the normal analysis produces combined plots/tables.
The top-level environment, bandwidth floors, limits and VkFFT exports are shared.
Copy/fetch the complete `results/<tag>/` tree to preserve those relative paths.

## Nsight Compute collection and summaries

The profile driver plans, restores and warms the selected config outside NVTX,
restores once more and synchronizes, then enqueues exactly one execution inside
`prof/<impl>/N<n>/b<batch>`. A legacy execution includes **all** host-loop batch
kernels. No timing/correctness/flush kernels are inside the range. The driver
works directly in one process in profile mode; ncu also uses
`--target-processes all`. CUDA runtime and driver launches are both intercepted,
so VkFFT's `cuLaunchKernel` calls are included. The command escapes literal
slashes, variant brackets and commas in the NVTX name, then adds the final
push/pop filter slash.

The NVTX range and original batch allocation still cover a full execution.
`--launch-count` bounds how many matching launches ncu replays; the application
finishes the remaining work without profiling it. Legacy uses one kernel per
batch for N<=1024 and five per batch for larger supported powers of two. The
default cap captures at most the first ten complete large-N batches (50
kernels). For example, N=2^16 with t25 has 512 batches and 2560 expected kernels,
but only 50 are captured; its extrapolation factor is 2560/50. These are launch
counts derived from the implementation, not measured performance estimates.
The command keeps the original full config, so sampling does not silently
replace its working set with a smaller allocation.

cuFFT/VkFFT normally complete below their 12-launch safety guard. A guard hit
fails the config with unknown expected total rather than treating a possibly
truncated execution as complete or inventing an extrapolation ratio. Bandwidth
copies each capture their known single launch. Actual counts are parsed from
the raw CSV, and legacy counts must match the planned complete-batch prefix.
fft2 captures exactly two launches per execution regardless of batch, with
`--launch-count 2`. Collection and analysis require `pass1_columns` followed by
`pass2_rows`; missing, extra or unrelated kernels fail rather than being sampled
or extrapolated. The escaped variant label must match the one used by the binary.

Primary captures use `--set full --cache-control all --clock-control none
--replay-mode kernel`. This makes replay passes reproducible by flushing GPU
caches and leaves GPU clocks under the host's existing policy. It is deliberately
different from the sweep's cold mode, which flushes once per **FFT**, rather than
before every profiled **kernel**. Every supported implementation also gets
`N=2^20,batch=1` with `--cache-control none` to examine reuse. With no-flush
kernel replay, state can vary between metric passes; this is a diagnostic
comparison, not a timing replacement for the sweep.

The bandwidth copy is profiled with total working sets 4096 MiB (two 2 GiB
buffers) and 16 MiB (two 8 MiB buffers). Both get cache-control all. The L2-sized
case also gets cache-control none after warmup, so that the traffic source can
be checked for hot L2 as well as cold replay. These sizes are chosen working
sets, not assumed measured cache/bandwidth results.

`run_ncu.sh` records the installed version, exact capture/import/query commands,
`--query-metrics --query-metrics-mode all` output, and full-set metric listing
in `ncu/`. Only queried supported metric names are appended explicitly to the
full set. Optional counters absent in an installed version do not invalidate the
whole capture. Each binary `.ncu-rep` is exported using
`ncu --import … --page raw --csv --print-units base`. `index.csv` maps raw CSVs
to implementation/config/cache-control/status, including unsupported legacy
configs. It also records `captured_kernels`, `expected_kernels`, `sampled`,
`capture_limit` and `kernels_per_batch`. An appended `impl_detail` column stores
the fft2 plan description printed by the profile worker (empty for other backends).
Captures and CSV exports have individual
logs too. An older index without sampling columns is interpreted as a complete
capture for backward-compatible analysis.

`ncu_summary.py` supports long metric-row CSV and wide metric-column CSV with
units rows, quoted thousands separators, profiler banners and repeated headers.
It identifies each launch by process/context/stream/ID, preserving repeated
kernel names. Missing metrics emit **NA and a warning**, including in aggregate
totals; no incomplete counter sum is presented as complete. Shared-memory byte
units include ncu 2025.3's `byte/block` and scaled byte-per-block forms, preserving
the per-block quantity. `lts__t_sectors.sum*32` is an
explicitly warned fallback if `lts__t_bytes.sum` is absent.

Per-config CSV and Markdown under `ncu/summary/` contain:

| Field group | Meaning |
| --- | --- |
| `impl,impl_detail,N,batch,batch_mode,cache_control,kernel_id,kernel` | Variant/config and resolved plan, replay policy, distinct launch ID, shortened demangled kernel name |
| `grid,block,registers_per_thread` | Grid/block tuple when exported, with launch-count metrics as fallback, and registers per thread |
| `static_smem_bytes,dynamic_smem_bytes,smem_bytes` | Shared memory per block and their sum |
| `duration_us,pct_config_time` | Profiled duration in microseconds and percent of the captured kernel-duration sum; sampling does not alter per-kernel values |
| `dram_read_bytes,dram_write_bytes,lts_bytes` | Per-launch DRAM and total L2 traffic |
| `dram_GBs,pct_measured_hbm_copy` | Historical `(DRAM read+write)/duration` and copy-limit percentage, retained for compatibility |
| `pct_mixed_hbm_limit` | Ideal read-plus-write service time at the separately measured peaks, divided by actual kernel duration, as a percentage |
| `l2_GBs,pct_measured_l2_copy` | `lts_bytes/duration` and historical L2 copy-limit percentage |
| `pct_l2_limit,l2_limit_method` | Total lts traffic normalized to the measured L2 read plateau; method is `total_lts_bytes/read_plateau` because a read/write sector split is not collected |
| `working_set_fits_l2` | Buffer proxy: `32*N*batch <= limits.json:l2_size_bytes`, or `48*N*batch` for fft2 out-of-place (input, workspace, output); excludes tables/library scratch; NA if cache size is unavailable or this is a bandwidth-copy profile |
| `sampled,captured_kernels,expected_kernels,sampling_ratio,extrapolation_factor` | Sampling flag/counts, captured/expected ratio and expected/captured scale |
| `theoretical_occupancy_pct,achieved_occupancy_pct` | Theoretical maximum and active-warps occupancy metrics |
| `shared_bank_conflicts_ld,shared_bank_conflicts_st,fp64_pipe_util_pct` | Shared load/store conflict counters and FP64 pipe utilization |
| `stall_1,stall_1_pct` through `stall_3,stall_3_pct` | Largest WarpStateStats stalled cycles per active warp percentages, descending |

With bytes in B, peaks in decimal GB/s and duration in microseconds, the new HBM
percentage is
`100*(dram_read_bytes/(1000*hbm_read_GBs) + dram_write_bytes/(1000*hbm_write_GBs))/duration_us`.
The L2 percentage is `100*lts_bytes/(1000*l2_read_GBs_plateau*duration_us)`.
Missing/nonpositive peaks or missing traffic/duration produce NA and a warning.
Values are never clipped to 100: counter traffic inflation, deferred writes,
measurement variability and differing cache policies remain visible. In
particular, the new formula alone does not guarantee every historical L4 value
will fall below 100%.

When `working_set_fits_l2` is true, the per-config Markdown displays:
"DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics."
The flag is a documented working-set proxy, not a proof that all library scratch
and temporaries are resident.

Each config table has a footer with total kernel time, total DRAM bytes and
the requested `effective_memory_passes = DRAM bytes/(2*16*N*batch)` raw traffic
ratio. `copy_calibration.csv` first audits observed DRAM/L2 bytes against the
known bandwidth-copy payload on this GPU. Footers also include
`dram_copy_traffic_factor` from the 4096 MiB, cache-all copy and
`calibrated_memory_passes = effective_memory_passes/dram_copy_traffic_factor`.
This exposes possible ECC/other counter traffic inflation called out in the
updated project plan. With no valid copy calibration, the calibrated field is
NA with a warning; the raw ratio must not be interpreted as an algorithmic
pass count. `config_totals.csv` collects those footers. These ratios describe
observed DRAM traffic, whereas
`pass_equiv` describes unprofiled elapsed time relative to the exact-size copy
floor. Neither is a claim about the implementation's algorithmic pass count.
Bandwidth-copy profiles have N/batch zero and an NA effective FFT-pass count.
For a sampled legacy config, `total_time_us`, `total_dram_bytes` and
`effective_memory_passes` scale the captured sums by `expected_kernels/captured_kernels`.
The CSV/Markdown retains `captured_time_us`, `captured_dram_bytes` and
`captured_effective_memory_passes`, marks `totals_extrapolated=true`, and prints
an extrapolation note. `kernel_count` remains the observed launch count.
Sampling uses the first complete batches and assumes their cost represents
later batches; extrapolated totals are estimates, especially for the no-flush
cache policy. Per-kernel metrics and captured-percent-of-time values are not
scaled. Count mismatches, partial legacy batches or an unknown sampling ratio
are errors instead of fabricated complete totals.
The summaries compare VkFFT launch counts to exported manifests when available
and report a mismatch as an analysis error after writing the tables.

If total binary report size exceeds 100,000,000 bytes, only `N=2^20` and `2^24`,
batch-one FFT reports are kept under results (including both cache policies).
Other binary reports move to an automatically created system temporary
directory; its exact location is printed and recorded in
`ncu/report_locations.json`. All raw CSVs and tables remain in results. Copy
the external reports elsewhere before the rented host's temporary storage is
removed if they are needed. No existing reports are overwritten.

`ERR_NVGPUCTRPERM` stops the ncu stage nonzero with an actionable message: have
the host administrator run the exact recorded capture command with `sudo -E`,
or configure `options nvidia NVreg_RestrictProfilingToAdminUsers=0` and reload
the driver modules/reboot. Container root alone may not grant host counter
access. The runner still attempts analysis and reports the failed ncu stage.

## Report

Generate a bottleneck report from an existing run without a GPU or new
measurements:

```bash
scripts/make_report.sh --tag smoke_l4_20261111
scripts/make_report.sh --tag a100_after --baseline-tag a100_before \
  --impls legacy,cufft,vkfft,fft2 --plots --out /tmp/fft-report.md
```

The default implementation list is `legacy,cufft,vkfft,fft2`. Output goes to
stdout unless `--out` names a **new** file in an existing directory. The wrapper
works from any working directory and honors `PYTHON`. The reporter never writes
to the input results directory, overwrites an existing report, or runs other
analysis/measurement scripts. `--results-root DIR` selects an alternate parent
of tag directories, useful for copied fixtures. `--plots` links only existing
PNGs beneath the current run's `plots/`, relative to the report's directory
(the current directory for stdout); it does not regenerate plots.

The header reads `env.txt`, `bandwidth/limits.json`, `ncu/version.txt`, and
`ncu/index.csv` / `ncu/commands.txt`. It records the captured date and clocks,
driver/toolkit/profiler versions, and recorded ncu cache/clock policies; it does
not infer settings from script defaults or infer a GPU from a tag. A GPU other
than a verified `A100-SXM4-40GB` (including missing GPU metadata) produces the
prominent **"smoke test, not official numbers"** banner. `NVIDIA ` is accepted
as a vendor prefix for that exact SKU. The compact historical L4 smoke run
omits environment/index/version captures, so its corresponding header cells
are deliberately unavailable.

The tables contain measured HBM read/write/copy and L2 read/copy limits,
plateau metadata, every per-size pass floor, unprofiled sweep medians, and
profiled launches. Sweep input is `sweep/raw.csv`, or `sweep/derived.csv` if raw
is absent. Joins preserve actual N, batch, batch label, timing mode and optional
`impl_detail`; variants are separate rows. Requested implementations without
measurements remain visible. `wrong`, `unsupported`, `error`, and missing
statuses cannot produce derived performance metrics. Speedup is
`t_cufft / t_impl`, and passes-equivalent is `t_impl / t_pass`, where `t_pass`
is the successful, same-key, same-mode **in-place** median from
`bandwidth/pass_floor.csv`. Times are displayed in microseconds.

Profiles prefer `ncu/summary/*.csv`, with fallback to normalized CSV/Markdown
tables directly under `ncu/`. This supports the older compact L4 exports and
the current T1 schema without changing either. Each distinct kernel launch
retains its time, DRAM/L2 bytes, achieved occupancy, shared load/store bank
conflicts, and two recorded largest stall reasons. Calibrated DRAM R/ideal and
W/ideal are `observed_direction_bytes / dram_traffic_factor / (16*N*batch)`.
The factor must come from the 4096 MiB, cache-all row of
`ncu/summary/copy_calibration.csv` (or the historical `ncu/copy_calibration.csv`);
no uncalibrated ratio is substituted when that file is missing.

Existing `pct_mixed_hbm_limit`, `pct_l2_limit` and `working_set_fits_l2` columns
are preserved, including explicitly unavailable values. If these columns are
absent from an older table, they are calculated directly from the recorded
traffic, duration, dimensions and measured limits using the formulas in the
Nsight Compute section above. DRAM percentages retain observed counter bytes;
calibration applies to the R/W pass ratios. Percentages and negative gaps are
never clipped. L2 residency uses the same conservative two-buffer proxy and
prints the deferred-write warning; it is not a claim about unknown library
workspace residency.

The sweep gap columns use
`gap_us = 1000*(t_impl_ms - calibrated_memory_passes*t_pass_ms)` and
`gap_pct = 100*gap_us/(1000*t_impl_ms)`. Passes come from the exact matching
`config_totals.csv` row, with the calibration CSV required; if only a raw
`effective_memory_passes` column exists, it is divided by the recorded factor.
Hot rows select ncu `cache_control=none`; cold rows select `all`. The reporter
never substitutes another policy, guesses an algorithmic pass count from an
implementation name or kernel count, or extrapolates a sampled profile.
Sampled/extrapolated totals cannot supply a measured gap. This is a comparison
with an **observed-traffic floor**, with the ncu-versus-sweep cache-policy
difference stated next to the table. For L2-resident configurations, DRAM passes
undercount deferred writes and this gap is not an algorithmic bandwidth bound;
use the per-kernel L2 metrics for assessment.

`--baseline-tag` adds the baseline's captured environment and compares only
shared configuration/variant/timing keys. Time delta is `after - before`, and
percentage delta is `100*(after-before)/before`; both rows must be `ok`.
An absent `impl_detail` is compatible with an empty detail, while different
named variants never match. Configurations exclusive to one run do not acquire
invented before/after values.

Missing files, columns, counters, invalid/nonpositive denominators, and absent
join partners produce `n/a` with footnotes naming their source file/column or
join key. No specification-sheet limits, interpolation, hardcoded performance
numbers, or implicit zero counters fill gaps. Duplicate join keys are errors.
The source-preserving fixture in `tests/fixtures/report/` records the main
commit it was copied from and includes a generated `golden.md` snapshot.
Temporary arithmetic/schema fixtures in tests are not new GPU results.

```bash
pytest tests -q
shellcheck scripts/make_report.sh
scripts/make_report.sh --tag smoke_l4_20261111
```

## Environment, validation and remaining GPU checks

`env.txt` records `nvidia-smi -q`, supported clocks, driver/GPU SKU/memory/ECC/
power/persistence/current clocks, nvcc and ncu versions, cuFFT version, VkFFT
tag/commit, repo commit and UID. The collector never attempts to change clocks
or privileges: whether clocks could actually be locked is explicitly
**unverified**, rather than inferred from a supported-clock list.

```bash
pytest tests -q
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck scripts/*.sh
scripts/run_t1_all.sh --tag test --dry-run
make bench TAG=t2b CUDA_ARCH=sm_80
# Force a rebuild when changing architecture under the same tag.
make -B bench TAG=t2b CUDA_ARCH=sm_89
```

CPU tests cover derivation units/joins/statuses, PNG generation, realistic ncu
CSV structures, missing counters/limits, units, kernel identity, export-count
mismatches, report retention, dry-run side effects, independent stage failures
and counter-permission errors. Fix-round regression tests cover bounded complete-
batch sampling, extrapolated totals, read-dominated HBM percentages, L2 residency
notes and ncu 2025.3 shared-memory units. Source review must also confirm the protected
legacy files/results are unchanged and the original default Makefile recipes
are unchanged. T2b validation on 2026-11-11: 81 tests passed; ShellCheck 0.11.0
reported no diagnostics; CUDA 13.5.37 compiled the harness for sm_80 and sm_89
with zero warnings. Added CPU cases exercise variant command lists, shared
build/calibration, continuation after worker failure, A100 candidate budgets,
quoted variant/detail fields, four-backend plots, merged profile paths and
exact two-pass capture validation. Fixtures are synthetic, not GPU measurements.

The next L4 gate (Claude/owner, later) is:

```bash
CUDA_ARCH=sm_89 scripts/run_t1_all.sh --tag t2b_l4 --quick
```

Require every `stage_status.csv` entry to be `OK` and every fft2 sweep row to be
`ok`. GPU confirmation remains necessary for cuFFT-relative error <= 1e-12,
in-place/out-of-place outputs, resolved device tile policies, matching escaped
NVTX filters, exactly two captured kernels, and populated counters. Follow with
custom splits/tiles and the variants runner (use L4-fitting candidates first).
No GPU runtime was allocated for the T2b authoring checks.

On the A100, confirm that all supported rows meet the tolerance, every requested
source export matches the captured launch count, core counters are populated,
the measured L2 curve/traffic validates the plateau rule, measured HBM agrees
with the device's reference bandwidth, and runtime fits the quick/full targets.
Specific assumptions requiring that run are VkFFT's retained `code0` and axis
function mapping in the pinned release, successful single-stream NVRTC/driver
execution, cuFFT/VkFFT sign/layout compatibility, escaped NVTX variant filter
matching in the installed ncu version, and availability of the requested sm_80
metrics. The source pins these choices; it supplies no GPU verification claims.

API references: [VkFFT pinned release/source](https://github.com/DTolm/VkFFT/tree/v1.3.4),
[Nsight Compute CLI filtering, metrics and replay settings](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html),
[CUDA 13 device-property API changes](https://developer.nvidia.com/blog/whats-new-and-important-in-cuda-toolkit-13-0/).
