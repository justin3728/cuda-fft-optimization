# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 30158:1:13:0 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 812.288 | 32.9701 | 5.36905e+08 | 5.20832e+08 | 2.13154e+09 | 1302.17 | 95.6027 | 2624.12 | 97.6232 | 25 | 24.43 | 76936 | 89039 | 49.5 | long_scoreboard | 33.13 | barrier | 11.85 | wait | 11.38 | 88.2182 | 93.5092 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 30158:1:13:1 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 781.888 | 31.7362 | 5.36905e+08 | 5.19481e+08 | 2.00793e+09 | 1351.07 | 99.1929 | 2568.05 | 95.5371 | 25 | 24.34 | 47462 | 125178 | 51.51 | long_scoreboard | 31.87 | wait | 11.82 | mio_throttle | 10.39 | 91.5329 | 91.5109 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 30158:1:13:2 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 869.536 | 35.2937 | 5.36892e+08 | 5.21054e+08 | 2.12674e+09 | 1216.68 | 89.3262 | 2445.83 | 90.9904 | 25 | 24.58 | 271926 | 621816 | 25.41 | long_scoreboard | 50.55 | barrier | 11.98 | mio_throttle | 11.73 | 82.4263 | 87.1558 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 3 | 2463.71 | 3.17207e+09 | 2.95422 | 0.996683 | 2.96405 | False | False | 3 | 3 | 1 | 1 | False | 2463.71 | 3.17207e+09 | 2.95422 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
