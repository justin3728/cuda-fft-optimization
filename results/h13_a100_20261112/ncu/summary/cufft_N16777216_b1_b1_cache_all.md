# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 24297:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 404.256 | 33.5529 | 2.68459e+08 | 2.50871e+08 | 1.01427e+09 | 1284.66 | 94.2404 | 2508.97 | 87.9824 | 25 | 24.22 | 40921 | 49588 | 32.81 | long_scoreboard | 53.85 | mio_throttle | 10.44 | wait | 8.94 | 86.9432 | 91.5435 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 24297:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 397.152 | 32.9633 | 2.68459e+08 | 2.52021e+08 | 1.0623e+09 | 1310.53 | 96.1386 | 2674.79 | 93.7973 | 25 | 24.23 | 42909 | 43122 | 33.29 | long_scoreboard | 50.66 | mio_throttle | 12.85 | wait | 9.08 | 88.6913 | 97.5938 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 24297:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 403.424 | 33.4838 | 2.68459e+08 | 2.5406e+08 | 1.06213e+09 | 1295.21 | 95.0146 | 2632.78 | 92.3241 | 25 | 24.27 | 54577 | 53198 | 24.06 | long_scoreboard | 52.33 | mio_throttle | 12.52 | barrier | 8.29 | 87.6489 | 96.0609 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 3 | 1204.83 | 1.56233e+09 | 2.91007 | 0.996675 | 2.91977 | False | False | 3 | 3 | 1 | 1 | False | 1204.83 | 1.56233e+09 | 2.91007 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
