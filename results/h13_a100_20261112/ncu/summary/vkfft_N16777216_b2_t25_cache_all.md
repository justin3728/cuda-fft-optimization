# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 25119:1:13:0 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 813.824 | 33.0844 | 5.36905e+08 | 5.20738e+08 | 2.13211e+09 | 1299.6 | 95.3364 | 2619.86 | 91.871 | 25 | 24.38 | 77826 | 95851 | 49.38 | long_scoreboard | 33.54 | barrier | 12.34 | wait | 11.39 | 87.9291 | 95.5895 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 25119:1:13:1 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 777.504 | 31.6079 | 5.36914e+08 | 5.19385e+08 | 1.97807e+09 | 1358.58 | 99.663 | 2544.13 | 89.2154 | 25 | 24.45 | 59476 | 94995 | 51.69 | long_scoreboard | 31.81 | wait | 11.77 | mio_throttle | 10.52 | 91.9215 | 92.8264 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 2 | t25 | all | 25119:1:13:2 | VkFFT_main | (8192, 2, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 868.512 | 35.3077 | 5.36892e+08 | 5.2113e+08 | 2.13398e+09 | 1218.2 | 89.3653 | 2457.05 | 86.1616 | 25 | 24.6 | 261538 | 596501 | 25.43 | long_scoreboard | 49.77 | barrier | 12.37 | mio_throttle | 11.87 | 82.4215 | 89.649 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 2 | t25 | all | 3 | 2459.84 | 3.17196e+09 | 2.95412 | 0.996675 | 2.96398 | False | False | 3 | 3 | 1 | 1 | False | 2459.84 | 3.17196e+09 | 2.95412 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
