# T4e A100 A/B (2026-11-13) — summary

A100-SXM4-40GB (Colab), CUDA 13.0, branch `codex/t4e-fft2-register-io` @ 886f800, sm_80. Hot medians of 15 trials (µs). ncu: `--cache-control all --clock-control none`, 2^20 and 2^24 (b1, t25). Only fft2 rows were timed; cuFFT was re-timed at 2^20/2^24 b1 as a machine check (92.4 / 1259.3 µs vs L006 92.5 / 1261.3 µs, < 0.2 %), so cuFFT/VkFFT columns cite L006 (`results/ab_a100_20261112/`).

Rows (all on `tile_policy=1 radix_mode=-1`, the T4d default):
- r0: `tw=1 cx=1 io=2`
- r1: `tw=1 cx=1 io=1`
- r2: `tw=1 cx=1 io=0`
- r3: `io=2` (tw=0 cx=0)

| N, batch | r0 | r1 | r2 | **r3** | L006 best fft2 | cuFFT (L006) | r3 % of cuFFT |
|---|---|---|---|---|---|---|---|
| 2^16 b1 | 13.8 | 14.9 | 18.5 | 19.6 | 14.9 | 14.0 | 71 % |
| 2^16 b8 | 32.7 | 41.5 | 43.5 | 32.8 | 35.1 | 25.4 | 77 % |
| 2^16 b512 | 1746.9 | 2164.1 | 2037.4 | 1611.2 | 1842.5 | 1596.6 | 99 % |
| 2^18 b1 | 32.1 | 38.2 | 34.0 | 29.2 | 36.1 | 23.7 | 81 % |
| 2^18 b8 | 173.5 | 202.8 | 194.0 | 138.4 | 163.9 | 126.3 | 91 % |
| 2^18 b128 | 2290.1 | 2885.9 | 2487.0 | 1760.5 | 2098.3 | 1615.3 | 92 % |
| 2^20 b1 | 122.4 | 127.8 | 139.0 | 93.5 | 107.6 | 92.5 | 99 % |
| 2^20 b8 | 799.9 | 812.9 | 893.2 | 614.7 | 749.7 | 513.2 | 83 % |
| 2^20 b32 | 3037.0 | 3100.2 | 3444.1 | 2320.0 | 2836.0 | 1833.4 | 79 % |
| 2^22 b1 | 556.5 | 632.5 | 771.0 | 374.2 | 457.1 | 320.7 | 86 % |
| 2^22 b8 | 3957.7 | 4511.3 | 5841.2 | 2545.5 | 3377.6 | 2032.4 | 80 % |
| 2^24 b1 | 3755.0 | 4100.2 | 4354.4 | 1844.6 | 2567.7 | 1261.3 | 68 % |
| 2^24 b8 | 30528.7 | 33427.6 | 34560.5 | 14225.0 | 20339.5 | 9913.7 | 70 % |
| 2^24 b2 | 7546.3 | 8367.9 | 8665.4 | 3622.3 | 5116.8 | 2496.5 | 69 % |

All rows `ok`, rel L2 4.4e-16 – 5.9e-16.

ncu 2^24 b1 (per kernel; ideal = 268 MB read + 268 MB write; HBM copy limit 1363 GB/s → 394 µs per pass):

| row | kernel | time µs | DRAM read MB | regs | shared ld/st bank conflicts | % of copy limit |
|---|---|---|---|---|---|---|
| r0 | pass1 | 2642.7 | 1196.4 | 96 | 16.0 M / 14.9 M | 15 % |
| r0 | pass2 | 1257.6 | 288.8 | 86 | 16.0 M / 14.9 M | 31 % |
| r3 | pass1 | 1190.7 | 270.3 | 164 | 0 / 6.3 M | 33 % |
| r3 | pass2 | 645.2 | 268.7 | 168 | 0.03 M / 14.7 M | 61 % |

Gate (same allocation): build PASS (0 warnings), 2430 kernels, max 255 regs; 36 spilling kernels, all `io=1` with lanes 5 or 7 (removed by 9dde298). `fft2_test --variants` 596 passed / 0 failed / 39 skipped.
