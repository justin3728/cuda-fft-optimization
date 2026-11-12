# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 15377:1:13:0 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 400.416 | 32.9315 | 2.68469e+08 | 2.51833e+08 | 1.05986e+09 | 1299.4 | 95.3512 | 2646.9 | 92.6103 | 25 | 24.31 | 39942 | 39652 | 50.47 | long_scoreboard | 32.8 | barrier | 11.64 | wait | 11.53 | 87.9842 | 96.5648 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 15377:1:13:1 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 384.928 | 31.6578 | 2.68469e+08 | 2.51009e+08 | 1.00209e+09 | 1349.54 | 99.0306 | 2603.31 | 91.085 | 25 | 24.19 | 31601 | 38535 | 52.59 | long_scoreboard | 33.82 | wait | 12.09 | barrier | 10.65 | 91.3816 | 94.9744 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 15377:1:13:2 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 430.56 | 35.4107 | 2.68456e+08 | 2.52439e+08 | 1.06346e+09 | 1209.81 | 88.7768 | 2469.95 | 86.419 | 25 | 24.38 | 120408 | 300117 | 25.79 | long_scoreboard | 49.61 | mio_throttle | 12.76 | barrier | 11.56 | 81.9162 | 90.1092 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 3 | 1215.9 | 1.56068e+09 | 2.90698 | 0.99669 | 2.91664 | False | False | 3 | 3 | 1 | 1 | False | 1215.9 | 1.56068e+09 | 2.90698 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
