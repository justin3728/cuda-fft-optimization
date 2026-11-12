# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 32 | t25 | all | 28259:1:13:0 | VkFFT_main | (128, 32, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 974.624 | 54.3099 | 5.36938e+08 | 5.20116e+08 | 2.14018e+09 | 1084.58 | 79.6275 | 2195.91 | 81.6926 | 12.5 | 12.07 | 0 | 0 | 47.75 | wait | 21.06 | lg_throttle | 19.25 | long_scoreboard | 19.18 | 73.4777 | 78.2499 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 32 | t25 | all | 28259:1:13:1 | VkFFT_main | (256, 32, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 819.936 | 45.6901 | 5.36913e+08 | 5.21489e+08 | 2.19404e+09 | 1290.84 | 94.7706 | 2675.87 | 99.5482 | 12.5 | 12.26 | 1.05393e+07 | 8.78045e+06 | 33.94 | long_scoreboard | 48.17 | wait | 15.36 | mio_throttle | 12.55 | 87.4496 | 95.353 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 32 | t25 | all | 2 | 1794.56 | 2.11546e+09 | 1.97017 | 0.996683 | 1.97673 | False | False | 2 | 2 | 1 | 1 | False | 1794.56 | 2.11546e+09 | 1.97017 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
