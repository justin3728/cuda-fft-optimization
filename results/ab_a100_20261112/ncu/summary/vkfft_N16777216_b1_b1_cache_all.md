# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 29604:1:13:0 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 402.88 | 33.0022 | 2.68469e+08 | 2.5184e+08 | 1.0603e+09 | 1291.47 | 94.8174 | 2631.79 | 97.9084 | 25 | 24.02 | 41926 | 44306 | 50.17 | long_scoreboard | 33.18 | wait | 11.59 | barrier | 11.57 | 87.5151 | 93.7823 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 29604:1:13:1 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 386.752 | 31.681 | 2.6847e+08 | 2.50931e+08 | 9.9983e+08 | 1342.98 | 98.599 | 2585.2 | 96.1751 | 25 | 24.18 | 31054 | 38056 | 52.38 | long_scoreboard | 33.24 | wait | 12.1 | barrier | 10.78 | 91.0078 | 92.122 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 29604:1:13:2 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 431.136 | 35.3168 | 2.68469e+08 | 2.52438e+08 | 1.0632e+09 | 1208.22 | 88.705 | 2466.05 | 91.7424 | 25 | 24.42 | 121498 | 289278 | 25.83 | long_scoreboard | 49.73 | mio_throttle | 12.36 | barrier | 11.67 | 81.872 | 87.8762 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 3 | 1220.77 | 1.56062e+09 | 2.90687 | 0.996683 | 2.91655 | False | False | 3 | 3 | 1 | 1 | False | 1220.77 | 1.56062e+09 | 2.90687 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
