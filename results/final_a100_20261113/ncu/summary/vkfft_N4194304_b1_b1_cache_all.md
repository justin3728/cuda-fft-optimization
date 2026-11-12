# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 8648:1:13:0 | VkFFT_main | (512, 1, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 172.032 | 59.3902 | 6.71749e+07 | 5.70134e+07 | 2.91829e+08 | 721.891 | 52.8793 | 1696.36 | 58.2052 | 25 | 23.38 | 21453 | 524288 | 38.99 | lg_throttle | 28.01 | math_pipe_throttle | 17.82 | long_scoreboard | 13.11 | 48.9506 | 60.1022 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 1 | b1 | all | 8648:1:13:1 | VkFFT_main | (1024, 1, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 117.632 | 40.6098 | 6.7146e+07 | 5.2804e+07 | 2.82497e+08 | 1019.71 | 74.6945 | 2401.53 | 82.4009 | 25 | 23.44 | 43165 | 2.16183e+06 | 34.53 | long_scoreboard | 25.81 | mio_throttle | 22.33 | barrier | 11.19 | 69.1834 | 85.0864 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 2 | 289.664 | 2.44138e+08 | 1.81897 | 0.996665 | 1.82506 | False | False | 2 | 2 | 1 | 1 | False | 289.664 | 2.44138e+08 | 1.81897 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
