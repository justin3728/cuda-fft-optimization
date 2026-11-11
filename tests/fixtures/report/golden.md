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
| 65536 | 1 | b1 | legacy | hot | 63.1296 | 0.727494 | 18.403 | ok | n/a[^missing-11] | n/a[^missing-11] | n/a[^missing-11] |
| 65536 | 1 | b1 | legacy | cold | 73.728 | 0.736111 | 4 | ok | n/a[^missing-12] | n/a[^missing-12] | n/a[^missing-12] |
| 65536 | 1 | b1 | cufft | hot | 45.9264 | 1 | 13.3881 | ok | n/a[^missing-13] | n/a[^missing-13] | n/a[^missing-13] |
| 65536 | 1 | b1 | cufft | cold | 54.272 | 1 | 2.94444 | ok | n/a[^missing-14] | n/a[^missing-14] | n/a[^missing-14] |
| 65536 | 1 | b1 | vkfft | hot | 66.56 | 0.69 | 19.403 | ok | n/a[^missing-15] | n/a[^missing-15] | n/a[^missing-15] |
| 65536 | 1 | b1 | vkfft | cold | 74.752 | 0.726027 | 4.05556 | ok | n/a[^missing-16] | n/a[^missing-16] | n/a[^missing-16] |
| 65536 | 1 | b1 | fft2 | hot | n/a[^missing-17] | n/a[^missing-18] | n/a[^missing-18] | n/a[^missing-19] | n/a[^missing-20] | n/a[^missing-18][^missing-20] | n/a[^missing-18][^missing-20] |
| 65536 | 1 | b1 | fft2 | cold | n/a[^missing-21] | n/a[^missing-22] | n/a[^missing-22] | n/a[^missing-23] | n/a[^missing-24] | n/a[^missing-22][^missing-24] | n/a[^missing-22][^missing-24] |
| 1048576 | 1 | b1 | legacy | hot | 604.365 | 1.16181 | 21.6587 | ok | 0.579634 | 588.191 | 97.3238 |
| 1048576 | 1 | b1 | legacy | cold | 738.304 | 1.06103 | 4.47826 | ok | 2.43259 | 337.257 | 45.68 |
| 1048576 | 1 | b1 | cufft | hot | 702.157 | 1 | 25.1633 | ok | 0.300485 | 693.772 | 98.8059 |
| 1048576 | 1 | b1 | cufft | cold | 783.36 | 1 | 4.75155 | ok | 1.06255 | 608.184 | 77.6378 |
| 1048576 | 1 | b1 | vkfft | hot | 561.766 | 1.24991 | 20.1321 | ok | 1.26527 | 526.46 | 93.7151 |
| 1048576 | 1 | b1 | vkfft | cold | 668.768 | 1.17135 | 4.05648 | ok | 1.58065 | 408.176 | 61.0341 |
| 1048576 | 1 | b1 | fft2 | hot | n/a[^missing-25] | n/a[^missing-26] | n/a[^missing-26] | n/a[^missing-27] | n/a[^missing-28] | n/a[^missing-26][^missing-28] | n/a[^missing-26][^missing-28] |
| 1048576 | 1 | b1 | fft2 | cold | n/a[^missing-29] | n/a[^missing-30] | n/a[^missing-30] | n/a[^missing-31] | n/a[^missing-32] | n/a[^missing-30][^missing-32] | n/a[^missing-30][^missing-32] |
| 16777216 | 1 | b1 | legacy | hot | n/a[^missing-33] | n/a[^missing-34] | n/a[^missing-34] | unsupported | n/a[^missing-35] | n/a[^missing-34][^missing-35] | n/a[^missing-34][^missing-35] |
| 16777216 | 1 | b1 | legacy | cold | n/a[^missing-36] | n/a[^missing-37] | n/a[^missing-37] | unsupported | n/a[^missing-38] | n/a[^missing-37][^missing-38] | n/a[^missing-37][^missing-38] |
| 16777216 | 1 | b1 | cufft | hot | 8901.43 | 1 | 4.00802 | ok | n/a[^missing-39] | n/a[^missing-39] | n/a[^missing-39] |
| 16777216 | 1 | b1 | cufft | cold | 8815.62 | 1 | 3.96728 | ok | n/a[^missing-40] | n/a[^missing-40] | n/a[^missing-40] |
| 16777216 | 1 | b1 | vkfft | hot | 9665.39 | 0.920959 | 4.35201 | ok | n/a[^missing-41] | n/a[^missing-41] | n/a[^missing-41] |
| 16777216 | 1 | b1 | vkfft | cold | 9612.26 | 0.917122 | 4.32579 | ok | n/a[^missing-42] | n/a[^missing-42] | n/a[^missing-42] |
| 16777216 | 1 | b1 | fft2 | hot | n/a[^missing-43] | n/a[^missing-44] | n/a[^missing-44] | n/a[^missing-45] | n/a[^missing-46] | n/a[^missing-44][^missing-46] | n/a[^missing-44][^missing-46] |
| 16777216 | 1 | b1 | fft2 | cold | n/a[^missing-47] | n/a[^missing-48] | n/a[^missing-48] | n/a[^missing-49] | n/a[^missing-50] | n/a[^missing-48][^missing-50] | n/a[^missing-48][^missing-50] |

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

### impl=legacy, N=1048576, batch=1, batch_mode=b1, cache_control=all

Source: `results/smoke_l4_20261111/ncu/legacy_N1048576_b1_b1_cache_all.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1577:1:13:0 | transpose_opt | 68.928 | 1.92402e+07 | 12544 | 0.995881 | 0.000649283 | 3.88412e+07 | 107.512 | 37.8974 | 77.26 | 9144 | 2986 | mio_throttle | 32.13 | mio_throttle_pipe_mio | 32.13 |
| 1577:1:13:1 | fft_block_1024_specialized | 202.656 | 1.85079e+07 | 52096 | 0.957976 | 0.00269651 | 4.07198e+07 | 35.2556 | 13.5132 | 47.31 | 524288 | 1.44179e+06 | tex_throttle | 59.02 | barrier | 13.46 |
| 1577:1:13:2 | transpose_and_twiddle | 180.768 | 1.86095e+07 | 896 | 0.963235 | 4.63773e-05 | 5.02919e+07 | 39.6259 | 18.7107 | 75.04 | 1429 | 1467 | tex_throttle | 44.84 | short_scoreboard | 33.05 |
| 1577:1:13:3 | fft_block_1024_specialized | 201.76 | 1.8528e+07 | 13184 | 0.959017 | 0.000682409 | 4.08557e+07 | 35.3723 | 13.6185 | 47.31 | 524288 | 1.44179e+06 | tex_throttle | 58.9 | barrier | 13.61 |
| 1577:1:13:4 | transpose_square_inplace | 69.12 | 1.90212e+07 | 8832 | 0.984545 | 0.000457148 | 4.11784e+07 | 105.972 | 40.0662 | 31.79 | 11191 | 4144 | long_scoreboard | 60.59 | long_scoreboard_pipe_l1tex | 60.59 |

### impl=legacy, N=1048576, batch=1, batch_mode=b1, cache_control=none

Source: `results/smoke_l4_20261111/ncu/legacy_N1048576_b1_b1_cache_none.md line 5`.

working_set_fits_l2: True (two-buffer proxy: 32 × N × batch ≤ L2 size).

> **L2-resident:** DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

| Kernel ID | Kernel | Time (µs) | DRAM read (B) | DRAM write (B) | DRAM R/ideal (cal.) | DRAM W/ideal (cal.) | L2 bytes | pct_mixed_hbm_limit | pct_l2_limit | Achieved occupancy (%) | Bank conflicts ld | Bank conflicts st | Stall 1 | Stall 1 (%) | Stall 2 | Stall 2 (%) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1894:1:13:0 | transpose_opt | 41.12 | 1.01972e+07 | 813440 | 0.527811 | 0.042104 | 3.99072e+07 | 103.476 | 65.2695 | 42.41 | 11228 | 16038 | mio_throttle | 29.3 | mio_throttle_pipe_mio | 29.3 |
| 1894:1:13:1 | fft_block_1024_specialized | 192.224 | 128 | 330752 | 6.62533e-06 | 0.0171199 | 4.09221e+07 | 0.698456 | 14.3174 | 47.25 | 524288 | 1.44179e+06 | tex_throttle | 62.78 | barrier | 13.62 |
| 1894:1:13:2 | transpose_and_twiddle | 176.896 | 9.77651e+06 | 1.11027e+06 | 0.506036 | 0.057468 | 5.05006e+07 | 23.8189 | 19.1995 | 73.54 | 1244 | 3284 | tex_throttle | 52.67 | short_scoreboard | 34.55 |
| 1894:1:13:3 | fft_block_1024_specialized | 192.736 | 512 | 89856 | 2.65013e-05 | 0.00465098 | 4.08351e+07 | 0.1902 | 14.249 | 47.17 | 524288 | 1.44179e+06 | tex_throttle | 62.79 | barrier | 13.5 |
| 1894:1:13:4 | transpose_square_inplace | 26.688 | 384 | 77696 | 1.9876e-05 | 0.00402158 | 4.0528e+07 | 1.18686 | 102.13 | 30.56 | 10501 | 29634 | long_scoreboard | 26.95 | long_scoreboard_pipe_l1tex | 26.95 |

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
[^missing-11]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('legacy', '65536', '1', 'b1', 'none', '').
[^missing-12]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('legacy', '65536', '1', 'b1', 'all', '').
[^missing-13]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '65536', '1', 'b1', 'none', '').
[^missing-14]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '65536', '1', 'b1', 'all', '').
[^missing-15]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '65536', '1', 'b1', 'none', '').
[^missing-16]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '65536', '1', 'b1', 'all', '').
[^missing-17]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-18]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-19]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, hot, ): missing status.
[^missing-20]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '65536', '1', 'b1', 'none', '').
[^missing-21]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-22]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-23]: results/smoke_l4_20261111/sweep/raw.csv (65536, 1, b1, fft2, cold, ): missing status.
[^missing-24]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '65536', '1', 'b1', 'all', '').
[^missing-25]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-26]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-27]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, hot, ): missing status.
[^missing-28]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '1048576', '1', 'b1', 'none', '').
[^missing-29]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-30]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-31]: results/smoke_l4_20261111/sweep/raw.csv (1048576, 1, b1, fft2, cold, ): missing status.
[^missing-32]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '1048576', '1', 'b1', 'all', '').
[^missing-33]: results/smoke_l4_20261111/sweep/raw.csv row 14: missing time_ms_median.
[^missing-34]: results/smoke_l4_20261111/sweep/raw.csv row 14: status=unsupported; derived metrics require ok.
[^missing-35]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('legacy', '16777216', '1', 'b1', 'none', '').
[^missing-36]: results/smoke_l4_20261111/sweep/raw.csv row 15: missing time_ms_median.
[^missing-37]: results/smoke_l4_20261111/sweep/raw.csv row 15: status=unsupported; derived metrics require ok.
[^missing-38]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('legacy', '16777216', '1', 'b1', 'all', '').
[^missing-39]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '16777216', '1', 'b1', 'none', '').
[^missing-40]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('cufft', '16777216', '1', 'b1', 'all', '').
[^missing-41]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '16777216', '1', 'b1', 'none', '').
[^missing-42]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('vkfft', '16777216', '1', 'b1', 'all', '').
[^missing-43]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): missing time_ms_median.
[^missing-44]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): status=missing; derived metrics require ok.
[^missing-45]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, hot, ): missing status.
[^missing-46]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '16777216', '1', 'b1', 'none', '').
[^missing-47]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): missing time_ms_median.
[^missing-48]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): status=missing; derived metrics require ok.
[^missing-49]: results/smoke_l4_20261111/sweep/raw.csv (16777216, 1, b1, fft2, cold, ): missing status.
[^missing-50]: results/smoke_l4_20261111/ncu/config_totals.csv: missing calibrated_memory_passes for ('fft2', '16777216', '1', 'b1', 'all', '').
