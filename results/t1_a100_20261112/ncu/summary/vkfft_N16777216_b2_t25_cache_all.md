# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 16132:1:13:0 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 816.992 | 33.0652 | 5.36905e+08 | 5.20783e+08 | 2.13148e+09 | 1294.61 | 94.9997 | 2608.94 | 91.2819 | 25 | 24.35 | 76177 | 93482 | 49.28 | long_scoreboard | 33.01 | barrier | 11.82 | wait | 11.32 | 87.6375 | 95.1797 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 16132:1:13:1 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 782.304 | 31.6614 | 5.36905e+08 | 5.19398e+08 | 1.97244e+09 | 1350.25 | 99.0821 | 2521.32 | 88.2162 | 25 | 24.37 | 53680 | 115899 | 51.53 | long_scoreboard | 32.18 | wait | 11.8 | mio_throttle | 10.46 | 91.4054 | 91.9831 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 16132:1:13:2 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 871.552 | 35.2734 | 5.36892e+08 | 5.20995e+08 | 2.13623e+09 | 1213.8 | 89.0694 | 2451.06 | 85.758 | 25 | 24.53 | 268935 | 614562 | 25.35 | long_scoreboard | 50.23 | barrier | 11.93 | mio_throttle | 11.74 | 82.1665 | 89.4199 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 3 | 2470.85 | 3.17188e+09 | 2.95404 | 0.99669 | 2.96385 | False | False | 3 | 3 | 1 | 1 | False | 2470.85 | 3.17188e+09 | 2.95404 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
