# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 7806:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 965.312 | 52.1732 | 5.36896e+08 | 5.201e+08 | 2.14659e+09 | 1094.98 | 80.2084 | 2223.73 | 76.3001 | 50 | 46.71 | 0 | 371 | 38.38 | math_pipe_throttle | 22.13 | long_scoreboard | 20.9 | lg_throttle | 15.2 | 74.1774 | 78.7867 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 32 | t25 | all | 7806:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 884.896 | 47.8268 | 5.36894e+08 | 5.20025e+08 | 2.15552e+09 | 1194.4 | 87.4911 | 2435.9 | 83.5802 | 50 | 47.58 | 147 | 1308 | 32.3 | long_scoreboard | 22.86 | lg_throttle | 19.81 | math_pipe_throttle | 17.49 | 80.9126 | 86.3041 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 2 | 1850.21 | 2.11391e+09 | 1.96874 | 0.996665 | 1.97532 | False | False | 2 | 2 | 1 | 1 | False | 1850.21 | 2.11391e+09 | 1.96874 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
