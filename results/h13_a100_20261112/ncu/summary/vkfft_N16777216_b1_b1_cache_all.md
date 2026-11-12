# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 24567:1:13:0 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 402.24 | 32.8954 | 2.68469e+08 | 2.5181e+08 | 1.06026e+09 | 1293.45 | 94.8858 | 2635.9 | 92.4332 | 25 | 24.09 | 36911 | 45278 | 50.32 | long_scoreboard | 32.63 | barrier | 11.98 | wait | 11.53 | 87.5361 | 96.1745 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 24567:1:13:1 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 385.824 | 31.5529 | 2.68469e+08 | 2.51007e+08 | 1.00119e+09 | 1346.41 | 98.7703 | 2594.94 | 90.9971 | 25 | 24 | 33759 | 40533 | 52.48 | long_scoreboard | 33.85 | wait | 12.11 | barrier | 10.51 | 91.122 | 94.6803 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 24567:1:13:2 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 434.72 | 35.5517 | 2.68456e+08 | 2.52463e+08 | 1.06339e+09 | 1198.29 | 87.9044 | 2446.16 | 85.7796 | 25 | 24.24 | 129407 | 294107 | 25.68 | long_scoreboard | 49.9 | mio_throttle | 12.33 | barrier | 11.72 | 81.0938 | 89.2515 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 3 | 1222.78 | 1.56067e+09 | 2.90698 | 0.996675 | 2.91668 | False | False | 3 | 3 | 1 | 1 | False | 1222.78 | 1.56067e+09 | 2.90698 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
