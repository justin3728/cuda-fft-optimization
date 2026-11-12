# T2 gate — Colab A100-SXM4-40GB (sm_80), 2026-11-12

Source: `notebooks/t2_gate.ipynb`, branch `codex/t2-two-pass-v1` @ 87597e8. Owner ran "Run all" (Colab UI, not the CLI); output pasted to Claude.
The occupancy table below comes from one extra ncu cell the owner ran on the same runtime. The run archive (`t2_gate_sm_80.tgz`) was not downloaded, so this file holds only the pasted text.

## Correctness gate (`fft2/fft2_test`)
```
GPU=NVIDIA A100-SXM4-40GB  ARCH=sm_80  commit=87597e8
build: OK
fft2_test exit: 0
SUMMARY passed=28 failed=0 skipped=1 api=PASS
  skip -> N=16777216 batch=8   (test's own 6 GiB device-memory cap, same as L4)
rel_l2 range: 4.52e-16 .. 6.05e-16  (gate 1e-12)
VERDICT: PASS
```

## ncu (one `execute()`, `--clock-control none`, default cache control)
The ratios are DRAM bytes / (16·N·batch). A100 copy-kernel calibration has **not** been measured yet (needs T1 full).

| config | kernel | read | write | time (µs) | eff BW (GB/s) |
|---|---|---:|---:|---:|---:|
| 2^24 b1 | pass1_columns | 1.00x | 0.95x | 1866.9 | 282 |
| 2^24 b1 | pass2_rows | 1.00x | 0.94x | 1349.8 | 387 |
| 2^22 b8 | pass1_columns | 1.00x | 0.98x | 3533.7 | 301 |
| 2^22 b8 | pass2_rows | 1.00x | 0.97x | 2595.5 | 408 |

- Each `execute()` launches exactly 2 kernels in both configs.
- Writes of slightly under 1.00x are consistent with part of the output still being in L2 when the kernel ends (inference).

## Occupancy (2^24 b1, ncu sections LaunchStats / Occupancy / WarpStateStats, `--clock-control none`)
| kernel | grid × block | regs/thread | smem config | block limit (smem / regs / warps) | theoretical occ. | achieved occ. | warp cycles / issued instr. |
|---|---|---:|---:|---|---:|---:|---:|
| pass1_columns | 2048 × 256 | 34 | 135.17 KB | **1** / 6 / 8 | 12.50% | 12.47% | 10.52 |
| pass2_rows | 2048 × 256 | 38 | 135.17 KB | **1** / 6 / 8 | 12.50% | 12.48% | 9.44 |

Shared memory limits occupancy to 1 block (8 warps) per SM. Registers alone would allow 6 blocks.
