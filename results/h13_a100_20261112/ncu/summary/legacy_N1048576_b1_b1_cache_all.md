# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 18020:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 21.024 | 11.4043 | 1.67835e+07 | 2.65728e+06 | 6.14858e+07 | 924.694 | 67.8341 | 2924.55 | 102.556 | 100 | 71.36 | 18610 | 8856 | 0 | mio_throttle | 32.43 | lg_throttle | 26.17 | long_scoreboard | 17.75 | 63.2502 | 106.706 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 18020:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.936 | 32.5117 | 1.67994e+07 | 897152 | 6.36711e+07 | 295.257 | 21.6596 | 1062.32 | 37.2524 | 37.5 | 35.07 | 526187 | 1.44409e+06 | 13.8 | mio_throttle | 34.8 | long_scoreboard | 17.62 | barrier | 16.27 | 20.2489 | 38.7602 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 18020:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 20.384 | 11.0571 | 1.67933e+07 | 2.43866e+06 | 5.96129e+07 | 943.485 | 69.2126 | 2924.49 | 102.553 | 100 | 79.76 | 17905 | 6933 | 37.43 | mio_throttle | 27.47 | long_scoreboard | 14.18 | lg_throttle | 14.12 | 64.555 | 106.704 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 18020:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.488 | 32.2687 | 1.67991e+07 | 446464 | 6.38432e+07 | 289.9 | 21.2666 | 1073.21 | 37.6344 | 37.5 | 35.08 | 526226 | 1.444e+06 | 13.85 | mio_throttle | 35.09 | long_scoreboard | 16.45 | barrier | 16.12 | 19.8966 | 39.1577 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 18020:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 23.52 | 12.7582 | 1.67814e+07 | 592896 | 6.36281e+07 | 738.705 | 54.1902 | 2705.28 | 94.8662 | 50 | 39.55 | 13716 | 6685 | 0 | mio_throttle | 28.75 | lg_throttle | 24.73 | long_scoreboard | 24.02 | 50.6865 | 98.7059 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 5 | 184.352 | 9.09892e+07 | 2.71169 | 0.996675 | 2.72074 | True | False | 5 | 5 | 1 | 1 | False | 184.352 | 9.09892e+07 | 2.71169 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
