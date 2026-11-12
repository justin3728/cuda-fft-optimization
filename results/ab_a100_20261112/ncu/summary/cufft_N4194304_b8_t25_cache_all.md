# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 28902:1:13:0 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 1120.19 | 55.6446 | 5.36908e+08 | 5.22449e+08 | 2.30578e+09 | 945.692 | 69.4309 | 2058.38 | 76.5764 | 50 | 48.01 | 0 | 1.25829e+07 | 34.28 | math_pipe_throttle | 20.04 | lg_throttle | 19.17 | long_scoreboard | 18.46 | 64.0665 | 73.3493 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 4194304 | 8 | t25 | all | 28902:1:13:1 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 892.928 | 44.3554 | 5.36918e+08 | 5.21993e+08 | 2.18149e+09 | 1185.89 | 87.0655 | 2443.08 | 90.8879 | 50 | 48.42 | 0 | 1.25829e+07 | 33.63 | mio_throttle | 20.65 | long_scoreboard | 18.84 | math_pipe_throttle | 18.23 | 80.3392 | 87.0577 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 2 | 2013.12 | 2.11827e+09 | 1.97279 | 0.996683 | 1.97936 | False | False | 2 | 2 | 1 | 1 | False | 2013.12 | 2.11827e+09 | 1.97279 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
