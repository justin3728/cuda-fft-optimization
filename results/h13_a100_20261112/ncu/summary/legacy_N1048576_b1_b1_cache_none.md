# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 18423:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 23.2 | 12.6087 | 1.6783e+07 | 9.39891e+06 | 7.25415e+07 | 1128.53 | 82.7871 | 3126.79 | 109.647 | 100 | 75.24 | 19931 | 5524 | 0 | mio_throttle | 32.15 | lg_throttle | 24.67 | long_scoreboard | 21.77 | 76.6691 | 114.085 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 18423:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.08 | 31.5652 | 2.79219e+06 | 2.82406e+06 | 6.17452e+07 | 96.6986 | 7.09366 | 1063.11 | 37.28 | 37.5 | 34.73 | 526401 | 1.44423e+06 | 14.15 | mio_throttle | 39.15 | barrier | 16.46 | lg_throttle | 12.5 | 6.54039 | 38.789 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 18423:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 25.408 | 13.8087 | 1.67937e+07 | 1.01719e+07 | 7.09419e+07 | 1061.3 | 77.8556 | 2792.11 | 97.9112 | 100 | 84.32 | 17992 | 4859 | 29.45 | mio_throttle | 31.42 | long_scoreboard | 17.59 | lg_throttle | 14.78 | 72.0616 | 101.874 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 18423:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.112 | 31.5826 | 2.13056e+06 | 2.17434e+06 | 6.20463e+07 | 74.0793 | 5.43434 | 1067.7 | 37.4412 | 37.5 | 34.72 | 526461 | 1.44409e+06 | 14.13 | mio_throttle | 39.24 | barrier | 16.26 | lg_throttle | 12.65 | 5.01014 | 38.9567 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 18423:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 19.2 | 10.4348 | 2.33843e+06 | 2.7904e+06 | 6.1563e+07 | 267.127 | 19.596 | 3206.41 | 112.439 | 50 | 35.36 | 13645 | 12818 | 0 | mio_throttle | 29.47 | lg_throttle | 28.13 | long_scoreboard | 17.09 | 18.0446 | 116.99 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 5 | 184 | 6.81975e+07 | 2.03244 | 0.996675 | 2.03923 | True | False | 5 | 5 | 1 | 1 | False | 184 | 6.81975e+07 | 2.03244 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
