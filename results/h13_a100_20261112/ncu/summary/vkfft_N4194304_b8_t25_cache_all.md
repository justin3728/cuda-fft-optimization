# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 24085:1:13:0 | VkFFT_main | (512, 8, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 1161.22 | 57.8811 | 5.36947e+08 | 5.55935e+08 | 2.40063e+09 | 941.153 | 69.0415 | 2067.34 | 72.4956 | 25 | 23.61 | 174172 | 4.1943e+06 | 42.33 | lg_throttle | 23.51 | math_pipe_throttle | 18.52 | long_scoreboard | 13.73 | 63.6452 | 75.4299 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 8 | t25 | all | 24085:1:13:1 | VkFFT_main | (1024, 8, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 844.992 | 42.1189 | 5.36909e+08 | 5.22284e+08 | 2.34437e+09 | 1253.49 | 91.9544 | 2774.43 | 97.2913 | 25 | 24.21 | 759503 | 1.74327e+07 | 36.27 | mio_throttle | 25.89 | long_scoreboard | 23.8 | barrier | 13.16 | 84.8079 | 101.229 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 2 | 2006.21 | 2.15207e+09 | 2.00428 | 0.996675 | 2.01096 | False | False | 2 | 2 | 1 | 1 | False | 2006.21 | 2.15207e+09 | 2.00428 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
