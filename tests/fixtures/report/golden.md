# Measurement report: smoke_l4_20261111

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
| ncu cache control | n/a[^missing-9] |
| ncu clock control | n/a[^missing-10] |

## Measured limits

Source: `results/smoke_l4_20261111/bandwidth/limits.json`. Bandwidth uses decimal GB/s.

| Measurement | Value |
| --- | --- |
| HBM read (GB/s) | 259.81 |
| HBM write (GB/s) | 246.442 |
| HBM copy, read + write (GB/s) | 242.747 |
| L2 read plateau (GB/s) | 1486.92 |
| L2 copy plateau (GB/s) | 1280.07 |
| L2 size (bytes) | 5.03316e+07 |
| L2 plateau range (MiB) | [4, 24] |
| L2 plateau rule | median of sampled points with 4 MiB &lt;= total distinct working set &lt;= reported L2 / 2 |

### Per-size pass floors

Source: `results/smoke_l4_20261111/bandwidth/pass_floor.csv`.

| N | Batch | Batch label | Timing | Copy kind | Median (µs) | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 65536 | 1 | b1 | hot | inplace | 3.4304 | ok |
| 65536 | 1 | b1 | cold | inplace | 18.432 | ok |
| 65536 | 1 | b1 | hot | outofplace | 3.4304 | ok |
| 65536 | 1 | b1 | cold | outofplace | 18.432 | ok |
| 1048576 | 1 | b1 | hot | inplace | 27.904 | ok |
| 1048576 | 1 | b1 | cold | inplace | 164.864 | ok |
| 1048576 | 1 | b1 | hot | outofplace | 28.6208 | ok |
| 1048576 | 1 | b1 | cold | outofplace | 173.056 | ok |
| 16777216 | 1 | b1 | hot | inplace | 2220.9 | ok |
| 16777216 | 1 | b1 | cold | inplace | 2222.08 | ok |
| 16777216 | 1 | b1 | hot | outofplace | 2219.57 | ok |
| 16777216 | 1 | b1 | cold | outofplace | 2234.37 | ok |

## FFT sweep

Source: `results/smoke_l4_20261111/sweep/raw.csv`. Times are unprofiled medians. Speedup = cuFFT time / implementation time; passes-equivalent = time / same-config, same-mode in-place pass floor. Derived metrics require status=ok.

Gap = implementation time − calibrated DRAM passes × pass floor; gap (%) = 100 × gap / implementation time. Passes come from config_totals.csv, with copy_calibration.csv required. Hot uses cache_control=none; cold uses all. These ncu replay policies differ from the sweep's cache handling, so this is an observed-traffic floor comparison, not an inferred algorithmic pass count. Sampled/extrapolated totals are unavailable for gaps. For L2-resident configs, deferred DRAM writes undercount passes; judge the per-kernel L2 metrics. Negative gaps are retained.

| N | Batch | Batch label | Impl | Timing | Median (µs) | Speedup vs cuFFT (×) | Passes-equivalent | Correctness status | Calibrated DRAM passes | Gap (µs) | Gap (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 65536 | 1 | b1 | cufft | hot | 45.9264 | 1 | 13.3881 | ok | n/a[^missing-11] | n/a[^missing-11] | n/a[^missing-11] |
| 65536 | 1 | b1 | cufft | cold | 54.272 | 1 | 2.94444 | ok | n/a[^missing-12] | n/a[^missing-12] | n/a[^missing-12] |
| 65536 | 1 | b1 | vkfft | hot | 66.56 | 0.69 | 19.403 | ok | n/a[^missing-13] | n/a[^missing-13] | n/a[^missing-13] |
| 65536 | 1 | b1 | vkfft | cold | 74.752 | 0.726027 | 4.05556 | ok | n/a[^missing-14] | n/a[^missing-14] | n/a[^missing-14] |
| 65536 | 1 | b1 | fft2 | hot | n/a[^missing-15] | n/a[^missing-16] | n/a[^missing-16] | n/a[^missing-17] | n/a[^missing-18] | n/a[^missing-16][^missing-18] | n/a[^missing-16][^missing-18] |
| 65536 | 1 | b1 | fft2 | cold | n/a[^missing-19] | n/a[^missing-20] | n/a[^missing-20] | n/a[^missing-21] | n/a[^missing-22] | n/a[^missing-20][^missing-22] | n/a[^missing-20][^missing-22] |
| 1048576 | 1 | b1 | cufft | hot | 702.157 | 1 | 25.1633 | ok | 0.300485 | 693.772 | 98.8059 |
| 1048576 | 1 | b1 | cufft | cold | 783.36 | 1 | 4.75155 | ok | 1.06255 | 608.184 | 77.6378 |
| 1048576 | 1 | b1 | vkfft | hot | 561.766 | 1.24991 | 20.1321 | ok | 1.26527 | 526.46 | 93.7151 |
| 1048576 | 1 | b1 | vkfft | cold | 668.768 | 1.17135 | 4.05648 | ok | 1.58065 | 408.176 | 61.0341 |
| 1048576 | 1 | b1 | fft2 | hot | n/a[^missing-23] | n/a[^missing-24] | n/a[^missing-24] | n/a[^missing-25] | n/a[^missing-26] | n/a[^missing-24][^missing-26] | n/a[^missing-24][^missing-26] |
| 1048576 | 1 | b1 | fft2 | cold | n/a[^missing-27] | n/a[^missing-28] | n/a[^missing-28] | n/a[^missing-29] | n/a[^missing-30] | n/a[^missing-28][^missing-30] | n/a[^missing-28][^missing-30] |
| 16777216 | 1 | b1 | cufft | hot | 8901.43 | 1 | 4.00802 | ok | n/a[^missing-31] | n/a[^missing-31] | n/a[^missing-31] |
| 16777216 | 1 | b1 | cufft | cold | 8815.62 | 1 | 3.96728 | ok | n/a[^missing-32] | n/a[^missing-32] | n/a[^missing-32] |
| 16777216 | 1 | b1 | vkfft | hot | 9665.39 | 0.920959 | 4.35201 | ok | n/a[^missing-33] | n/a[^missing-33] | n/a[^missing-33] |
| 16777216 | 1 | b1 | vkfft | cold | 9612.26 | 0.917122 | 4.32579 | ok | n/a[^missing-34] | n/a[^missing-34] | n/a[^missing-34] |
| 16777216 | 1 | b1 | fft2 | hot | n/a[^missing-35] | n/a[^missing-36] | n/a[^missing-36] | n/a[^missing-37] | n/a[^missing-38] | n/a[^missing-36][^missing-38] | n/a[^missing-36][^missing-38] |
| 16777216 | 1 | b1 | fft2 | cold | n/a[^missing-39] | n/a[^missing-40] | n/a[^missing-40] | n/a[^missing-41] | n/a[^missing-42] | n/a[^missing-40][^missing-42] | n/a[^missing-40][^missing-42] |

## Per-kernel profiles

NCU replay durations are distinct from sweep times. DRAM R/ideal and W/ideal divide observed bytes by the same-GPU HBM-copy traffic factor and by 16 × N × batch bytes per direction. Percentages retain observed counter traffic, without calibration or clipping. Older tables without the percentage columns use 100 × (R/(1000 × HBM read GB/s) + W/(1000 × HBM write GB/s)) / duration_us and 100 × L2 bytes / (1000 × L2 read plateau GB/s × duration_us). A present but unavailable percentage remains n/a.

| Calibration source | HBM-copy DRAM traffic factor |
| --- | --- |
| results/smoke_l4_20261111/ncu/copy_calibration.csv | 1.15155 |

### impl=cufft, N=1048576, batch=1, batch_mode=b1, cache_control=all

Source: `results/smoke_l4_20261111/ncu/cufft_N1048576_b1_b1_cache_all.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2212:1:13:0 | regular_fft_factor&lt;1024, EPT&lt;8&gt;, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder&gt; | 413.92 | 1.99338e+07 | 256 | 1.03178 | 1.32507e-05 | 3.43234e+07 | 18.5363 | 5.57682 | 65.61 | 0 | 131072 | tex_throttle | 74.24 | lg_throttle | 9.74 |
| 2212:1:13:1 | regular_fft_factor&lt;1024, EPT&lt;8&gt;, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder&gt; | 338.944 | 2.11224e+07 | 0 | 1.0933 | 0 | 3.43276e+07 | 23.9861 | 6.81127 | 65.7 | 0 | 131072 | tex_throttle | 70.1 | lg_throttle | 14.21 |

### impl=cufft, N=1048576, batch=1, batch_mode=b1, cache_control=none

Source: `results/smoke_l4_20261111/ncu/cufft_N1048576_b1_b1_cache_none.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2376:1:13:0 | regular_fft_factor&lt;1024, EPT&lt;8&gt;, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder&gt; | 383.264 | 5888 | 116608 | 0.000304765 | 0.00603568 | 3.4325e+07 | 0.12937 | 6.02317 | 65.74 | 0 | 131072 | tex_throttle | 87.33 | short_scoreboard | 3.04 |
| 2376:1:13:1 | regular_fft_factor&lt;1024, EPT&lt;8&gt;, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder&gt; | 312.832 | 1.00584e+07 | 1.42976e+06 | 0.520627 | 0.074005 | 3.43288e+07 | 14.23 | 7.38006 | 63.7 | 0 | 131072 | tex_throttle | 84.47 | lg_throttle | 3.78 |

### impl=vkfft, N=1048576, batch=1, batch_mode=b1, cache_control=all

Source: `results/smoke_l4_20261111/ncu/vkfft_N1048576_b1_b1_cache_all.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2544:1:13:0 | VkFFT_main | 341.632 | 4.01475e+07 | 2.20314e+06 | 2.07805 | 0.114035 | 5.12031e+07 | 47.8486 | 10.0798 | 8.2 | 0 | 131072 | tex_throttle | 45.98 | short_scoreboard | 23.33 |
| 2544:1:13:1 | VkFFT_main | 288.48 | 1.87099e+07 | 14976 | 0.968432 | 0.000775164 | 3.44677e+07 | 24.9842 | 8.03543 | 8.32 | 292224 | 265139 | short_scoreboard | 42.44 | tex_throttle | 33.03 |

### impl=vkfft, N=1048576, batch=1, batch_mode=b1, cache_control=none

Source: `results/smoke_l4_20261111/ncu/vkfft_N1048576_b1_b1_cache_none.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2712:1:13:0 | VkFFT_main | 324.544 | 1.9766e+07 | 1.72342e+07 | 1.0231 | 0.892049 | 5.12031e+07 | 44.9895 | 10.6105 | 7.48 | 0 | 131072 | tex_throttle | 53.3 | short_scoreboard | 27.34 |
| 2712:1:13:1 | VkFFT_main | 269.28 | 1.10181e+07 | 871296 | 0.570301 | 0.0450986 | 3.4518e+07 | 17.0617 | 8.62093 | 8.1 | 298095 | 275608 | short_scoreboard | 47.96 | tex_throttle | 37.33 |

## Missing data

[^missing-1]: results/smoke_l4_20261111/env.txt: missing gpu_name; results/smoke_l4_20261111/bandwidth/limits.json: missing gpu_name.
[^missing-2]: results/smoke_l4_20261111/env.txt: missing driver_version; results/smoke_l4_20261111/bandwidth/limits.json: missing driver_version.
[^missing-3]: results/smoke_l4_20261111/env.txt: missing cuda_version; results/smoke_l4_20261111/bandwidth/limits.json: missing cuda_version.
[^missing-4]: results/smoke_l4_20261111/env.txt: missing ncu_version; results/smoke_l4_20261111/bandwidth/limits.json: missing ncu_version.
[^missing-5]: results/smoke_l4_20261111/env.txt: missing date; results/smoke_l4_20261111/bandwidth/limits.json: missing date.
[^missing-6]: results/smoke_l4_20261111/env.txt: missing Clocks/SM.
[^missing-7]: results/smoke_l4_20261111/env.txt: missing Clocks/Graphics.
[^missing-8]: results/smoke_l4_20261111/env.txt: missing Clocks/Memory.
[^missing-9]: results/smoke_l4_20261111/ncu/index.csv:cache_control and results/smoke_l4_20261111/ncu/commands.txt:--cache-control missing.
[^missing-10]: results/smoke_l4_20261111/ncu/index.csv:clock_control and results/smoke_l4_20261111/ncu/commands.txt:--clock-control missing.
[^missing-11]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '65536', '1', 'b1', 'none', '').
[^missing-12]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '65536', '1', 'b1', 'all', '').
[^missing-13]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '65536', '1', 'b1', 'none', '').
[^missing-14]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '65536', '1', 'b1', 'all', '').
[^missing-15]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-16]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-17]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): missing status.
[^missing-18]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '65536', '1', 'b1', 'none', '').
[^missing-19]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-20]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-21]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): missing status.
[^missing-22]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '65536', '1', 'b1', 'all', '').
[^missing-23]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-24]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-25]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): missing status.
[^missing-26]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '1048576', '1', 'b1', 'none', '').
[^missing-27]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-28]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-29]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): missing status.
[^missing-30]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '1048576', '1', 'b1', 'all', '').
[^missing-31]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '16777216', '1', 'b1', 'none', '').
[^missing-32]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '16777216', '1', 'b1', 'all', '').
[^missing-33]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '16777216', '1', 'b1', 'none', '').
[^missing-34]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '16777216', '1', 'b1', 'all', '').
[^missing-35]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-36]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-37]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): missing status.
[^missing-38]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '16777216', '1', 'b1', 'none', '').
[^missing-39]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-40]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-41]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): missing status.
[^missing-42]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '16777216', '1', 'b1', 'all', '').
