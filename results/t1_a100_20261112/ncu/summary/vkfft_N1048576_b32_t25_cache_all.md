# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 32 | t25 | all | 13417:1:13:0 | VkFFT_main | (128, 32, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 969.216 | 54.1476 | 5.36939e+08 | 5.20067e+08 | 2.14049e+09 | 1090.58 | 80.0275 | 2208.48 | 77.2705 | 12.5 | 12.09 | 0 | 0 | 48 | wait | 21.26 | long_scoreboard | 19.16 | lg_throttle | 19.11 | 73.8264 | 80.57 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 32 | t25 | all | 13417:1:13:1 | VkFFT_main | (256, 32, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 820.736 | 45.8524 | 5.36913e+08 | 5.21505e+08 | 2.19201e+09 | 1289.6 | 94.6315 | 2670.78 | 93.4457 | 12.5 | 12.27 | 1.05483e+07 | 8.78156e+06 | 33.95 | long_scoreboard | 48.24 | wait | 15.34 | mio_throttle | 12.44 | 87.2969 | 97.4358 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 32 | t25 | all | 2 | 1789.95 | 2.11542e+09 | 1.97014 | 0.99669 | 1.97668 | False | False | 2 | 2 | 1 | 1 | False | 1789.95 | 2.11542e+09 | 1.97014 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
