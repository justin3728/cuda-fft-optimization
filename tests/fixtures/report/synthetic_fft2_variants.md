# Measurement report: synthetic_fft2_variants

> [!WARNING]
> **smoke test, not official numbers** — GPU is not verified as A100-SXM4-40GB.

| Environment | Captured value |
| --- | --- |
| GPU | n/a[^missing-1] |
| Driver | n/a[^missing-2] |
| CUDA toolkit | n/a[^missing-3] |
| Nsight Compute | n/a[^missing-4] |
| Date captured | n/a[^missing-5] |
| Current SM clock | n/a[^missing-6] |
| Current graphics clock | n/a[^missing-7] |
| Current memory clock | n/a[^missing-8] |
| ncu cache control | all, none |
| ncu clock control | none |

## Measured limits

Source: `results/synthetic_fft2_variants/bandwidth/limits.json`. Bandwidth uses decimal GB/s.

| Measurement | Value |
| --- | --- |
| HBM read (GB/s) | 2 |
| HBM write (GB/s) | 4 |
| HBM copy, read + write (GB/s) | 3 |
| L2 read plateau (GB/s) | 8 |
| L2 copy plateau (GB/s) | 6 |
| L2 size (bytes) | 8192 |
| L2 plateau range (MiB) | synthetic fixture only |
| L2 plateau rule | synthetic CPU constants, not a measured plateau |

### Per-size pass floors

Source: `results/synthetic_fft2_variants/bandwidth/pass_floor.csv`.

| N | Batch | Batch label | Timing | Copy kind | Median (µs) | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 128 | 1 | b1 | hot | inplace | 1 | ok |
| 128 | 1 | b1 | cold | inplace | 2 | ok |

## FFT sweep

Source: `results/synthetic_fft2_variants/sweep/raw.csv`. Times are unprofiled medians. Speedup = cuFFT time / implementation time; passes-equivalent = time / same-config, same-mode in-place pass floor. Derived metrics require status=ok.

Gap = implementation time − calibrated DRAM passes × pass floor; gap (%) = 100 × gap / implementation time. Passes come from config_totals.csv, with copy_calibration.csv required. Hot uses cache_control=none; cold uses all. These ncu replay policies differ from the sweep's cache handling, so this is an observed-traffic floor comparison, not an inferred algorithmic pass count. Sampled/extrapolated totals are unavailable for gaps. For L2-resident configs, deferred DRAM writes undercount passes; judge the per-kernel L2 metrics. Negative gaps are retained.

| N | Batch | Batch label | Impl | Timing | Median (µs) | Speedup vs cuFFT (×) | Passes-equivalent | Correctness status | Calibrated DRAM passes | Gap (µs) | Gap (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 128 | 1 | b1 | cufft | hot | 8 | 1 | 8 | ok | n/a[^missing-9] | n/a[^missing-9] | n/a[^missing-9] |
| 128 | 1 | b1 | cufft | cold | 20 | 1 | 10 | ok | n/a[^missing-10] | n/a[^missing-10] | n/a[^missing-10] |
| 128 | 1 | b1 | fft2[n1=0,c=0,r=0] | hot | 4 | 2 | 4 | ok | 3 | 1 | 25 |
| 128 | 1 | b1 | fft2[n1=0,c=0,r=0] | cold | 8 | 2.5 | 4 | ok | 3 | 2 | 25 |
| 128 | 1 | b1 | fft2[n1=1024,c=4,r=8,oop=1] | hot | 2 | 4 | 2 | ok | 1 | 1 | 50 |
| 128 | 1 | b1 | fft2[n1=1024,c=4,r=8,oop=1] | cold | 4 | 5 | 2 | ok | 1 | 2 | 50 |

## Per-kernel profiles

NCU replay durations are distinct from sweep times. DRAM R/ideal and W/ideal divide observed bytes by the same-GPU HBM-copy traffic factor and by 16 × N × batch bytes per direction. Percentages retain observed counter traffic, without calibration or clipping. Older tables without the percentage columns use 100 × (R/(1000 × HBM read GB/s) + W/(1000 × HBM write GB/s)) / duration_us and 100 × L2 bytes / (1000 × L2 read plateau GB/s × duration_us). A present but unavailable percentage remains n/a.

| Calibration source | HBM-copy DRAM traffic factor |
| --- | --- |
| results/synthetic_fft2_variants/ncu/copy_calibration.csv | 1 |

### impl=fft2[n1=0,c=0,r=0], N=128, batch=1, batch_mode=b1, cache_control=all

Source: `results/synthetic_fft2_variants/ncu/summary/fft2_variants.csv row 8`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch0 | synthetic_auto_pass1 | 4 | 2048 | 2048 | 1 | 1 | 4096 | 38.4 | 12.8 | 12.5 | 0 | 0 | barrier | 20 | long_scoreboard | 10 |
| launch1 | synthetic_auto_pass2 | 4 | 4096 | 4096 | 2 | 2 | 8192 | 76.8 | 25.6 | 12.5 | 0 | 0 | barrier | 20 | long_scoreboard | 10 |

### impl=fft2[n1=0,c=0,r=0], N=128, batch=1, batch_mode=b1, cache_control=none

Source: `results/synthetic_fft2_variants/ncu/summary/fft2_variants.csv row 6`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch0 | synthetic_auto_pass1 | 2 | 2048 | 2048 | 1 | 1 | 4096 | 76.8 | 25.6 | 12.5 | 0 | 0 | barrier | 20 | long_scoreboard | 10 |
| launch1 | synthetic_auto_pass2 | 2 | 4096 | 4096 | 2 | 2 | 8192 | 153.6 | 51.2 | 12.5 | 0 | 0 | barrier | 20 | long_scoreboard | 10 |

### impl=fft2[n1=1024,c=4,r=8,oop=1], N=128, batch=1, batch_mode=b1, cache_control=all

Source: `results/synthetic_fft2_variants/ncu/summary/fft2_variants.csv row 4`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch0 | synthetic_oop_pass1 | 2 | 1024 | 1024 | 0.5 | 0.5 | 2048 | 38.4 | 12.8 | 25 | 0 | 0 | barrier | 10 | long_scoreboard | 5 |
| launch1 | synthetic_oop_pass2 | 2 | 1024 | 1024 | 0.5 | 0.5 | 2048 | 38.4 | 12.8 | 25 | 0 | 0 | barrier | 10 | long_scoreboard | 5 |

### impl=fft2[n1=1024,c=4,r=8,oop=1], N=128, batch=1, batch_mode=b1, cache_control=none

Source: `results/synthetic_fft2_variants/ncu/summary/fft2_variants.csv row 2`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| launch0 | synthetic_oop_pass1 | 1 | 1024 | 1024 | 0.5 | 0.5 | 2048 | 76.8 | 25.6 | 25 | 0 | 0 | barrier | 10 | long_scoreboard | 5 |
| launch1 | synthetic_oop_pass2 | 1 | 1024 | 1024 | 0.5 | 0.5 | 2048 | 76.8 | 25.6 | 25 | 0 | 0 | barrier | 10 | long_scoreboard | 5 |

## Before / after

### Baseline environment: synthetic_fft2_variants

> [!WARNING]
> **smoke test, not official numbers** — GPU is not verified as A100-SXM4-40GB.

| Environment | Captured value |
| --- | --- |
| GPU | n/a[^missing-1] |
| Driver | n/a[^missing-2] |
| CUDA toolkit | n/a[^missing-3] |
| Nsight Compute | n/a[^missing-4] |
| Date captured | n/a[^missing-5] |
| Current SM clock | n/a[^missing-6] |
| Current graphics clock | n/a[^missing-7] |
| Current memory clock | n/a[^missing-8] |
| ncu cache control | all, none |
| ncu clock control | none |

Before: `results/synthetic_fft2_variants/sweep/raw.csv`. After: `results/synthetic_fft2_variants/sweep/raw.csv`. Only exact shared (N, batch, batch label, impl, impl_detail, timing mode) keys are compared. An absent impl_detail matches an empty detail. Delta = after − before; delta (%) = 100 × delta / before. Negative time deltas mean less elapsed time. Deltas require both statuses to be ok.

| N | Batch | Batch label | Impl | Timing | Before (µs) | After (µs) | Delta (µs) | Delta (%) | Before status | After status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 128 | 1 | b1 | cufft | cold | 20 | 20 | 0 | 0 | ok | ok |
| 128 | 1 | b1 | cufft | hot | 8 | 8 | 0 | 0 | ok | ok |
| 128 | 1 | b1 | fft2[n1=0,c=0,r=0] | cold | 8 | 8 | 0 | 0 | ok | ok |
| 128 | 1 | b1 | fft2[n1=0,c=0,r=0] | hot | 4 | 4 | 0 | 0 | ok | ok |
| 128 | 1 | b1 | fft2[n1=1024,c=4,r=8,oop=1] | cold | 4 | 4 | 0 | 0 | ok | ok |
| 128 | 1 | b1 | fft2[n1=1024,c=4,r=8,oop=1] | hot | 2 | 2 | 0 | 0 | ok | ok |

## Missing data

[^missing-1]: results/synthetic_fft2_variants/env.txt: missing gpu_name; results/synthetic_fft2_variants/bandwidth/limits.json: missing gpu_name.
[^missing-2]: results/synthetic_fft2_variants/env.txt: missing driver_version; results/synthetic_fft2_variants/bandwidth/limits.json: missing driver_version.
[^missing-3]: results/synthetic_fft2_variants/env.txt: missing cuda_version; results/synthetic_fft2_variants/bandwidth/limits.json: missing cuda_version.
[^missing-4]: results/synthetic_fft2_variants/env.txt: missing ncu_version; results/synthetic_fft2_variants/bandwidth/limits.json: missing ncu_version.
[^missing-5]: results/synthetic_fft2_variants/env.txt: missing date; results/synthetic_fft2_variants/bandwidth/limits.json: missing date.
[^missing-6]: results/synthetic_fft2_variants/env.txt: missing Clocks/SM.
[^missing-7]: results/synthetic_fft2_variants/env.txt: missing Clocks/Graphics.
[^missing-8]: results/synthetic_fft2_variants/env.txt: missing Clocks/Memory.
[^missing-9]: results/synthetic_fft2_variants/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '128', '1', 'b1', 'none', '').
[^missing-10]: results/synthetic_fft2_variants/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '128', '1', 'b1', 'all', '').
