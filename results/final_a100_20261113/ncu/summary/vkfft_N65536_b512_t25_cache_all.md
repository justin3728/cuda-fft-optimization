# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 6143:1:13:0 | VkFFT_main | (64, 512, 1) | (8, 16, 1) | 84 | 0 | 16384 | 16384 | 766.4 | 48.8277 | 5.36893e+08 | 5.20394e+08 | 2.13589e+09 | 1379.55 | 101.054 | 2786.91 | 95.6241 | 31.25 | 30.27 | 30044 | 47468 | 49.63 | long_scoreboard | 48.91 | wait | 9.46 | barrier | 7.33 | 93.4548 | 98.7405 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 65536 | 512 | t25 | all | 6143:1:13:1 | VkFFT_main | (16, 512, 1) | (8, 64, 1) | 64 | 0 | 73728 | 73728 | 803.2 | 51.1723 | 5.36888e+08 | 5.19984e+08 | 2.16479e+09 | 1315.83 | 96.3858 | 2695.2 | 92.4772 | 50 | 48.42 | 833247 | 669684 | 30.87 | long_scoreboard | 23.37 | mio_throttle | 20.38 | barrier | 19.01 | 89.1385 | 95.491 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 2 | 1569.6 | 2.11416e+09 | 1.96896 | 0.996665 | 1.97555 | False | False | 2 | 2 | 1 | 1 | False | 1569.6 | 2.11416e+09 | 1.96896 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
