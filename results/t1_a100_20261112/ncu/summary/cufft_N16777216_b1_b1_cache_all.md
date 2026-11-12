# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 15101:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 404.896 | 33.5757 | 2.68459e+08 | 2.50814e+08 | 1.01121e+09 | 1282.48 | 94.1097 | 2497.47 | 87.3818 | 25 | 23.87 | 38871 | 51129 | 32.74 | long_scoreboard | 52.8 | mio_throttle | 10.36 | wait | 8.89 | 86.8413 | 91.113 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 15101:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 397.6 | 32.9707 | 2.6846e+08 | 2.51891e+08 | 1.06182e+09 | 1308.73 | 96.0355 | 2670.57 | 93.4382 | 25 | 24.07 | 39332 | 40315 | 33.15 | long_scoreboard | 50.5 | mio_throttle | 12.87 | wait | 9.11 | 88.6154 | 97.428 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 15101:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 403.424 | 33.4536 | 2.6846e+08 | 2.54034e+08 | 1.06189e+09 | 1295.15 | 95.039 | 2632.19 | 92.0955 | 25 | 24.21 | 54459 | 54327 | 23.96 | long_scoreboard | 51.91 | mio_throttle | 12.38 | barrier | 8.09 | 87.6903 | 96.0281 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 3 | 1205.92 | 1.56212e+09 | 2.90967 | 0.99669 | 2.91933 | False | False | 3 | 3 | 1 | 1 | False | 1205.92 | 1.56212e+09 | 2.90967 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
