# Two-pass FP64 forward FFT (v1)

This isolated CUDA C++17 implementation targets `sm_80` (A100), with an
`sm_89` (L4) build target for correctness smoke tests. It accepts natural-order
complex doubles, produces an unnormalized natural-order forward transform,
and supports `N = 2^16 .. 2^24` and `batch >= 1`.

**T4a variants are CPU-tested and compile with zero warnings for `sm_80` and
`sm_89` using CUDA 13.5. GPU variant correctness, test duration, launch traces,
and physical memory traffic remain unverified locally. No performance result
is claimed.** The variant GPU gate below must be run by Claude, on L4 first;
H9/H10 need a separate A100 measurement before any default changes.

## Build and gates

```bash
python3 -m pip install numpy pytest
make -C fft2 test-cpu
# Equivalent, from the repository root:
python3 -m pytest fft2/reference -q

make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test
make -C fft2 CUDA_ARCH=sm_80 && fft2/fft2_test
# T4a GPU gate (Claude, L4):
make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test --variants
fft2/fft2_test --describe
fft2/fft2_test --variants --describe
```

The Makefile uses `-std=c++17`, `-Xcompiler=-Wall,-Wextra,-Werror`, and
`-Werror=all-warnings` (CUDA 13). An older nvcc that rejects the latter can use
`NVCC_WARNING_FLAGS=`; host warnings still fail the build. Objects live under
`build/<arch>/`; the executable is relinked on each build so switching back to
an already-built architecture selects the right objects. Use `make -B` after
changing compiler flags. The repository's root Makefile is untouched.

`fft2_test` checks all 27 `(N, batch)` combinations for exponents 16..24 and
batch 1, 3, 8, plus two custom-split/tile cases. It compares out-of-place and
in-place execution to `CUFFT_Z2Z` forward on a nonblocking stream. One line per
configuration contains both relative L2 errors and maximum absolute errors,
or an explicit memory-cap skip/failure reason. The final `SUMMARY` counts
passed/failed/skipped configurations and API checks. Any nonfinite result,
relative L2 error above `1e-12`, API-check failure, or zero executed
configurations causes a nonzero exit status. `--describe` only prints the nine
default batch-1 plan descriptions and a summary; it does not execute FFTs.

`--variants` runs that same full list of 29 configurations for every
`index_mode` in `{0,1}` and `smem_padding` in `{0,1,2}`: 174 configuration
outcomes, including explicit skips. Each line identifies both axes, the
requested split/tiles, and either the actual plan/errors or the skip/failure
reason. Per-axis summaries and a final total follow. Any failure, API failure,
or axis with no passing configurations makes the exit status nonzero. Shared
memory is checked before allocation; only combinations that cannot fit even
one automatic lane (or the explicitly requested widths) are skipped for that
reason. Unexpected plan/CUDA errors fail the gate.

To keep the L4 gate bounded, variants share one random input and one cuFFT
reference per configuration, use one fft2 plan at a time, and execute only one
out-of-place plus one in-place transform per variant. The input stays intact;
a device copy restores the output buffer before the in-place test. The target
is under approximately three minutes on L4; elapsed GPU test time still needs
to be checked there. `--variants --describe` describes all feasible default
batch-1 variant plans and lists the infeasible combinations without FFTs.

The default device cap is 6144 MiB, further limited to 90% of currently free
VRAM. The test queries exact cuFFT scratch requirements with automatic
allocation disabled, then budgets two data buffers, the FFT workspace,
cuFFT scratch, and a 16 MiB reserve for tables/overhead. The default host cap
is 2048 MiB: one full reference array plus a bounded 16 MiB comparison tile.
Large combinations exceeding either cap are logged as skips. For example:

```bash
fft2/fft2_test --max-device-mib 12288 --max-host-mib 4096
```

The CPU tests cover every power `2^4 .. 2^20`, three splits where distinct
(including equal factors and `N1 < N2`), and batch 1 and 3 at a `1e-13` relative
L2 threshold. They also test local FFT lengths 2..4096, 64-bit cross-exponent
reduction, impulses/DC/tones, partial tiles, and both devices' modeled budgets.
Eight full-transform cases for `N >= 2^21` are marked `slow` and skipped by
default. Enable them with `--run-slow` or `make -C fft2 test-cpu-slow`; these
can require several GiB of host memory. Windows NumPy may implement
`longdouble` as double; the table-only rounding check accounts for this while
the full-transform tolerance stays `1e-13`.

Local T4a CPU validation on 2026-11-11 (NumPy 2.3.5, pytest 9.2.0):

```text
make -C fft2 test-cpu
585 passed, 8 skipped in 25.90s
```

The eight opt-in slow tests were not rerun for T4a. The new tests exercise
both index modes and all padding values for local FFT lengths 2..4096 and
partial tiles, sample complete production transforms, check physical layout
offsets/padding holes, and check the A100/L4 budgets for every production
size. A separate comparison against the v1 CPU model at the base commit
`87597e8` matched default output bytes in ten configurations (including
nondividing custom tiles); this is CPU evidence, not a GPU bitwise gate.

## API and lifetime

```cpp
#include "fft2/fft2.h"

fft2::Plan plan(size_t{1} << 20, 3);
plan.execute(device_input, device_output, stream);
// Check/synchronize stream before consuming results or destroying the plan.
```

`PlanOptions{n1, tile_cols, tile_rows}` uses 0 for automatic selection. The
default split is `N1 = 2^floor(log2(N)/2)`, `N2 = N/N1`. Explicit splits must
have both factors powers of two in 256..4096. Explicit tile widths can be any
positive integer up to the corresponding dimension if they fit shared
memory; nondividing widths use zero-filled inactive lanes and guarded global
accesses in the last tile. The automatic widths are powers of two up to 8.

Construction validates sizes, byte-count overflow, grid limits, and shared
memory; allocates `16*N*batch` workspace bytes; and uploads twiddle tables.
It never reads transform input/output. Table initialization finishes before
construction returns, including for subsequent nonblocking-stream execution.
`execute()` allocates/copies nothing and enqueues exactly two kernels on the
provided stream. Runtime/launch errors throw `std::runtime_error`; asynchronous
device errors are reported when the caller synchronizes. A plan is bound to
its creation device and owns a single workspace: executions of the same plan
must not overlap. Different plans can use different streams. Input and output
may be the same pointer: pass 1 finishes before pass 2 on the same stream.
`workspace_bytes()` excludes tables. `describe()` prints the split, tile
widths, variant axes, grid/block dimensions and dynamic shared bytes for each
kernel.

## Tuning variants

Both axes are opt-in hypotheses. `PlanOptions{}` retains v1's `size_t`
division/remainder, unpadded layout, automatic tile policy, and floating-point
operation order. The new fields are appended, so existing three-field
aggregate initializers retain their meaning.

```cpp
fft2::PlanOptions options;
options.index_mode = 1;    // H9: u32 shift/mask for power-of-two divisors
options.smem_padding = 1;  // H10: one unused complex element per element-row
fft2::Plan candidate(size_t{1} << 20, 3, options);
std::cout << candidate.describe() << '\n';
candidate.execute(device_input, device_output, stream);
```

| Option | Values | Hypothesis / behavior |
|---|---|---|
| `index_mode` | `0` (default), `1` | **H9:** replacing runtime 64-bit division/remainder with u32 shift/mask may reduce integer instruction overhead. Mode 1 uses u32 for block-local indices and offsets within one transform, including cross-table indexing; the batch base/global address stays 64-bit. |
| `smem_padding` | `0` (default), `1`, `2` | **H10:** changing the shared row stride from `lanes` to `lanes+padding` may reduce shared-memory bank conflicts. Each padding unit is one unused FP64 complex element per element-row, so allocation is `length*(lanes+padding)*16` bytes. |

Each kernel is specialized at compile time for both axes. Dispatch happens
on the host once per launch; there are no mode/padding branches in hot loops.
Mode 1 also has a separate specialization for explicit non-power-of-two tile
widths (such as 3 or 5): lane quotient/remainder use u32 division there, while
FFT lengths, butterfly spans, and cross-table divisors still use shift/mask.
No explicit-width configuration is silently rounded to a power of two.
Production bounds (`N <= 2^24`, `column < N2`, `k1 < N1`) ensure
`column*k1 < N` and all within-transform offsets fit u32. Mode 0 retains v1's
64-bit arithmetic. Unsupported axis values throw before device allocation.

Automatic tile selection accounts for padding and halves lanes until the
allocation fits the queried opt-in limit. It never reduces explicit widths;
an infeasible plan throws before workspace allocation. Calculated examples:

- A100's modeled 163 KiB limit, length 4096: padding 0 chooses two lanes
  (128 KiB); padding 1 chooses one lane (128 KiB); padding 2 cannot fit one
  lane (192 KiB).
- L4's modeled 99 KiB limit, length 2048: padding 0 chooses two lanes
  (64 KiB); padding 2 chooses one lane (96 KiB). Length 4096 cannot fit even
  one lane with padding 1 or 2.

Thus L4's `N >= 2^23` automatic splits skip padding 1/2 in the variant gate;
A100's `N = 2^24` split skips padding 2. These are modeled resource limits,
not measured performance. The CPU model allocates physical padded storage,
uses `shared_index()` for accesses, and poisons padding with NaNs to expose
accidental padding reads.

To accept/reject these hypotheses, Claude must measure on **A100-SXM4-40GB**:

1. First run the full variant correctness gate, and record wall time on L4
   against the approximately three-minute target. On A100 record N, batch,
   split, actual C/R, padding, shared bytes, and the two-kernel launch trace.
   Use the same input, build flags, clock policy (`--clock-control none`),
   and explicit cache policy for every pair.
2. **H9:** compare mode 0 against mode 1 with padding fixed and identical
   C/R. For **each pass**, collect `gpu__time_duration`,
   `smsp__inst_executed` (including its `.sum` aggregate), and
   `sass__inst_executed_per_opcode` / source-correlated SASS instruction
   counts. Inspect IMAD and the full instruction sequences implementing
   integer division/remainder, plus register count and local-memory spills.
   Fewer relevant instructions with lower kernel time supports H9 as a
   bottleneck; unchanged sequences or unchanged time rejects that explanation
   for the measured configuration. Instruction changes alone do not justify
   selecting a default.
3. **H10:** hold index mode and C/R fixed, compare padding 0/1/2 wherever
   all compared allocations fit. For each pass collect
   `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum` and
   `l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_st.sum`, shared
   load/store instruction or request counts, kernel time, registers/spills,
   achieved occupancy, and barrier/LSU stalls. Compare conflicts per request
   as well as totals. Reduced conflicts with lower time supports H10 as a
   bottleneck; unchanged conflicts or no time benefit rejects the proposed
   fix as a default for that case. Separately measure automatic tiles and
   report any lane shrinkage, grid changes, and occupancy cost; those pairs
   cannot isolate padding's effect.
4. Include all supported exponents 16..24 and batches 1/3/8 where memory
   permits, with repeated event timings (hot and cold policies recorded).
   Include `2^20` batch 1 (judge L2) and `2^24` batch 1 / `2^22` batch 8
   (judge large-working-set traffic using measured limits). Record DRAM/L2
   read/write bytes and calibrate DRAM bytes with the same GPU's copy kernel.
   Report unsupported combinations explicitly and preserve raw ncu evidence.
   Keep both defaults at zero until this evidence supports a separate change.

## Exact decomposition and layouts

Let `N = N1*N2`, `n = N2*n1 + n2`, `k = k1 + N1*k2`, and
`W_M = exp(-2*pi*i/M)`. The implementation follows:

```text
X[k1 + N1*k2] = sum_n2 W_N2^(n2*k2) *
                 (W_N^(n2*k1) * sum_n1 x[N2*n1+n2] * W_N1^(n1*k1))

One batch of input, row-major:       Workspace Y, row-major:
                n2 ->                                n2 ->
 n1=0   x[0,0] x[0,1] ...            k1=0   Y[0,0] Y[0,1] ...
 n1=1   x[1,0] x[1,1] ...            k1=1   Y[1,0] Y[1,1] ...
          |      |                            ----------->
          v      v                       pass 2: row FFTs
      pass 1: column FFTs

Natural-order output, flattened as k = k1 + N1*k2:
                 k1 ->
 k2=0   X[0]     X[1]     ... X[N1-1]
 k2=1   X[N1]    X[N1+1]  ... X[2*N1-1]
```

Pass 1 loads `C` consecutive columns into shared memory, runs a length-`N1`
FFT on each column, multiplies the cross twiddle, and writes the same
`[k1,n2]` positions in Y. Pass 2 loads `R` consecutive Y rows, runs length-`N2`
FFTs, and writes the output with adjacent `k1` values for each fixed `k2`.
Shared memory supplies the different load/store orders inside each kernel;
there is no transpose kernel or global intermediate beyond Y.

For batch index `b`, **all** global offsets below include `base = b*N`.
The side-by-side formulas are the review cross-check between
`reference/two_pass_model.py` and the two CUDA kernels:

| Operation | Flat tile index and global offset (Python and CUDA) |
|---|---|
| Pass 1 load | `element=flat/C`, `lane=flat%C`, `n2=tile*C+lane`; `base+element*N2+n2` |
| Pass 1 store | `k1=flat/C`, `lane=flat%C`, `n2=tile*C+lane`; `base+k1*N2+n2` |
| Pass 2 load | `lane=flat/N2`, `element=flat%N2`, `k1=tile*R+lane`; `base+k1*N2+element` |
| Pass 2 store | `k2=flat/R`, `lane=flat%R`, `k1=tile*R+lane`; `base+k1+N1*k2` |

Integer `/` in that table means floor division. Shared layout is
`shared[element*(lanes+padding)+lane]`, initially populated at
`element=bit_reverse(input_element)` and finally in natural order. Padding is
0 by default and opt-in 1 or 2 for H10; `shared_index()` and `shared_bytes()`
use the same stride in CUDA and the CPU model.
The Python model explicitly executes the per-tile load and store maps and
uses the same local butterfly formulas, rather than replacing either global
pass with a transpose of a fully transformed array.

Within a block, binary bit reversal feeds in-place DIT. A thread loads four
values `a0..a3` at quarter-span spacing into registers. With
`q=span/4`, `w1=W_span^j`, `w2=W_span^(2*j)`:

```text
u0 = a0 + w2*a1        u1 = a0 - w2*a1
u2 = w1*(a2+w2*a3)    u3 = -i*w1*(a2-w2*a3)
shared[start]     = u0+u2     shared[start+q]   = u1+u3
shared[start+2*q] = u0-u2     shared[start+3*q] = u1-u3
```

These are two fused radix-2 stages (a radix-4 stage). Disjoint butterfly sets
write in place, followed by a block barrier. Odd `log2(length)` uses one final
radix-2 stage. No second shared tile is needed. The CPU local-FFT tests compare
these formulas against NumPy for every length used by production kernels.

`grid.x` selects the column/row tile. Batch uses
`b=blockIdx.y+gridDim.y*blockIdx.z` with a uniform out-of-range guard, so batch
counts beyond grid.y's limit can use grid.z. There is no host batch loop in
`execute()`. In mode 0, counts, flat offsets and byte arithmetic use `size_t`
and the cross product is 64-bit. Mode 1 uses u32 for local counts, offsets and
the bounded cross product; global batch offsets and byte counts stay 64-bit.

At source level, each element is read once/written once by each pass:
input -> Y -> output, or **64*N*batch logical data bytes** for two read/write
passes (excluding twiddle traffic). This describes the algorithm. Physical
DRAM/L2 transactions, spills and cache effects still need GPU measurement.

## Twiddle tables

Within-pass tables hold `W_N1^j` and `W_N2^j`, precomputed on the host in
`long double` and stored as complex FP64 in device global memory. Kernel
loads use the read-only path (`__ldg` on the two double components). They are
not included in the shared tile budget.

The cross twiddle uses `B=2^ceil(log2(N)/2)`, a low table of B entries
`low[j]=W_N^j` and a high table of N/B entries `high[j]=W_N^(j*B)`:

```text
a = (uint64_t(n2) * uint64_t(k1)) % uint64_t(N)
W_N^a = high[a / B] * low[a % B]
```

Both tables are O(sqrt(N)); even an explicitly asymmetric split uses B
derived from N. Host angles are formed as `-2*pi*(integer_exponent % N)/N`
before any floating-point trigonometry. No large unreduced product becomes
an angle. The NumPy table construction uses the same integer reduction and
long-double angle calculation. All four tables together use at most 256 KiB
over the supported range; only the workspace scales with batch.

## Shared-memory budgets (automatic split and tiles)

These are **calculated allocation sizes**, not measurements. The policy
chooses the largest power-of-two tile width <= 8 fitting the device's queried
`cudaDevAttrMaxSharedMemoryPerBlockOptin` limit. Each pass needs exactly
`length*(lanes+padding)*16` bytes; the table below uses default padding 0.
The reference tests check these budgets for all three padding values.

| log2 N | N1 x N2 | A100 C / R | A100 pass 1 / 2 KiB | L4 C / R | L4 pass 1 / 2 KiB |
|---:|---:|---:|---:|---:|---:|
| 16 | 256 x 256 | 8 / 8 | 32 / 32 | 8 / 8 | 32 / 32 |
| 17 | 256 x 512 | 8 / 8 | 32 / 64 | 8 / 8 | 32 / 64 |
| 18 | 512 x 512 | 8 / 8 | 64 / 64 | 8 / 8 | 64 / 64 |
| 19 | 512 x 1024 | 8 / 8 | 64 / 128 | 8 / 4 | 64 / 64 |
| 20 | 1024 x 1024 | 8 / 8 | 128 / 128 | 4 / 4 | 64 / 64 |
| 21 | 1024 x 2048 | 8 / 4 | 128 / 128 | 4 / 2 | 64 / 64 |
| 22 | 2048 x 2048 | 4 / 4 | 128 / 128 | 2 / 2 | 64 / 64 |
| 23 | 2048 x 4096 | 4 / 2 | 128 / 128 | 2 / 1 | 64 / 64 |
| 24 | 4096 x 4096 | 2 / 2 | 128 / 128 | 1 / 1 | 64 / 64 |

The assumed opt-in limits are 163 KiB for A100 and 99 KiB for L4; the plan
always queries the actual device. All A100 automatic tiles have C,R >= 2.
On L4, two 4096-point FFTs would require 128 KiB, so singleton tiles are
unavoidable with this full-tile shared representation: R=1 at `2^23`,
C=R=1 at `2^24`. Those paths cannot provide a two-element contiguous global
segment for the strided direction. This is a documented v1 fallback, to be
checked for correctness rather than treated as a performance result.

Dynamic shared memory is used for every tile. The plan opts both kernels in
using `cudaFuncSetAttribute(..., cudaFuncAttributeMaxDynamicSharedMemorySize,
device_limit)` when the limit exceeds 48 KiB, following the
[CUDA shared-memory guidance](https://docs.nvidia.com/cuda/cuda-programming-guide/03-advanced/advanced-kernel-programming.html).
Setting the full device limit avoids a later small plan lowering the kernel
limit needed by an existing larger plan. Actual per-launch allocation remains
the tile size in the table. Explicit tiles exceeding the limit throw a clear
error before workspace allocation or execution.

## Known performance questions for the A100 run

- What shared-memory bank conflicts occur during bit reversal, radix-4
  exchanges and pass-2 layout changes? Would a padding change help?
- What register count and any local-memory spills does nvcc generate? Does
  each configuration meet the intended two-pass data-traffic structure?
- How do the tile widths and 256-thread blocks affect occupancy, barriers
  and achieved memory transactions?
- What cost comes from repeated read-only twiddle loads, 64-bit index
  division/modulo and cross-table products?
- Would different splits or C/R widths improve memory access and scheduling
  after correctness is confirmed?
- Do launch traces show exactly two kernels per `execute()` for every batch,
  and do calibrated L2/DRAM counters match the logical pass count for working
  sets much larger than L2 (`2^24` batch 1, `2^22` batch 8)?

The GPU run must confirm the numerical gate on L4 and A100, shared-memory
opt-in/resource feasibility, nonblocking-stream initialization, natural-order
in-place/batched output, and the launch/traffic assumptions above before
anything is reported as GPU verified.
