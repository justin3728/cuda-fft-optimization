# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 23420:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 22.976 | 12.4157 | 1.67827e+07 | 9.43846e+06 | 7.25953e+07 | 1141.24 | 83.7878 | 3159.61 | 117.545 | 100 | 75.81 | 19560 | 5976 | 0 | mio_throttle | 32.47 | lg_throttle | 25.31 | long_scoreboard | 22.11 | 77.6155 | 112.591 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 23420:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.752 | 31.7482 | 2.83341e+06 | 3.00416e+06 | 6.19881e+07 | 99.3595 | 7.29478 | 1055.08 | 39.2513 | 37.5 | 34.76 | 526428 | 1.44414e+06 | 14.06 | mio_throttle | 38.46 | barrier | 16.5 | lg_throttle | 12.72 | 6.72694 | 37.5972 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 23420:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 25.888 | 13.9893 | 1.6793e+07 | 1.01083e+07 | 7.10166e+07 | 1039.14 | 76.2916 | 2743.22 | 102.054 | 100 | 83.13 | 17230 | 4980 | 29.18 | mio_throttle | 31.21 | long_scoreboard | 17.5 | lg_throttle | 14.81 | 70.639 | 97.7533 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 23420:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.336 | 31.5234 | 2.15693e+06 | 2.32166e+06 | 6.19359e+07 | 76.7724 | 5.63647 | 1061.71 | 39.498 | 37.5 | 34.7 | 526636 | 1.44407e+06 | 14.09 | mio_throttle | 39.01 | barrier | 16.6 | lg_throttle | 12.67 | 5.19715 | 37.8335 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 23420:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 19.104 | 10.3234 | 2.26522e+06 | 2.70656e+06 | 6.13011e+07 | 260.248 | 19.1069 | 3208.81 | 119.375 | 50 | 35.5 | 13039 | 12529 | 0 | mio_throttle | 29.16 | lg_throttle | 27.7 | long_scoreboard | 16.84 | 17.6042 | 114.344 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 5 | 185.056 | 6.84104e+07 | 2.03879 | 0.996683 | 2.04557 | True | False | 5 | 5 | 1 | 1 | False | 185.056 | 6.84104e+07 | 2.03879 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
