# fft2: two-pass FP64 forward FFT

```cpp
#include "fft2.h"

fft2::Plan plan(n, batch);              // n = 2^16 .. 2^24, batch >= 1
plan.execute(d_in, d_out, stream);      // cuDoubleComplex*, in == out allowed
```

Forward, unnormalized, natural order in and out. The plan owns a workspace of
`n * batch` elements and four small twiddle tables; executions on one plan must
not overlap.

## Algorithm

`N = N1 x N2` with `N1 = 2^floor(log2 N / 2)`. Viewing the input as an
`N1 x N2` row-major matrix:

1. **Pass 1 (`pass1_columns`)**: length-`N1` FFTs down the columns, then
   multiply by the cross twiddle `W_N^(column * k1)`, write to the workspace.
2. **Pass 2 (`pass2_rows`)**: length-`N2` FFTs along the rows of the workspace,
   written transposed so the output is in natural order.

Each pass reads and writes the array exactly once, so the whole transform moves
2 reads + 2 writes of the data, the minimum for a two-pass design.

Inside a pass, one 256-thread block transforms a tile of `Lanes` FFTs:

- **Tile size** (`detail/tile_policy.h`): the largest power of two of lanes
  whose tile fits 32 KiB, at least 2 (one lane only if two do not fit the
  device's shared memory). Small tiles keep several blocks per SM resident.
- **Register I/O**: values go from global memory straight into registers and the
  first radix stage runs there; the last radix stage also runs in registers
  right before the global store. Only the stages in between go through shared
  memory, one barrier per stage.
- **Radix**: radix-16 butterflies when every thread of the block gets at least
  one, otherwise radix-8.
- **Twiddles**: precomputed in long double on the host. The cross twiddle uses
  two short tables (`W_N^e = W_N^(high) * W_N^(low)`) that stay in L2/L1, instead of
  one length-`N` table.

## Tests

```bash
make -C fft2 test-cpu        # host tile-policy test + NumPy model (CPU only)
make -C fft2 CUDA_ARCH=sm_80 && fft2/fft2_test   # GPU: compare with cuFFT
```

- `reference/model.py` is a NumPy model of the CUDA kernels, index map by index
  map (thread to element, shared-memory layout, stage plan, twiddle exponents).
  Its tests check it against `numpy.fft`, check that every shared-memory slot is
  written exactly once per stage, and check coalescing assumptions.
- `fft2_test` runs every `N = 2^16 .. 2^24` with batch 1, 3 and 8, both out of
  place and in place, against cuFFT (relative L2 error <= 1e-12; measured
  values are below 1e-15).
