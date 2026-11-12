# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 10755:1:13:0 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 810.048 | 32.9245 | 5.36905e+08 | 5.20724e+08 | 2.13059e+09 | 1305.64 | 95.6395 | 2630.2 | 90.247 | 25 | 24.32 | 73580 | 79950 | 49.49 | long_scoreboard | 33.26 | mio_throttle | 11.56 | wait | 11.38 | 88.4474 | 93.1882 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 10755:1:13:1 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 785.312 | 31.9191 | 5.36905e+08 | 5.19441e+08 | 1.985e+09 | 1345.13 | 98.5322 | 2527.66 | 86.7286 | 25 | 24.29 | 55923 | 110853 | 51.27 | long_scoreboard | 32.12 | wait | 11.8 | mio_throttle | 10.6 | 91.1243 | 89.5551 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 10755:1:13:2 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 864.96 | 35.1564 | 5.36892e+08 | 5.20974e+08 | 2.13638e+09 | 1223.02 | 89.5878 | 2469.92 | 84.7475 | 25 | 24.68 | 265214 | 607452 | 25.43 | long_scoreboard | 50.37 | barrier | 11.83 | mio_throttle | 11.82 | 82.8505 | 87.5094 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 3 | 2460.32 | 3.17184e+09 | 2.95401 | 0.996665 | 2.96389 | False | False | 3 | 3 | 1 | 1 | False | 2460.32 | 3.17184e+09 | 2.95401 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
