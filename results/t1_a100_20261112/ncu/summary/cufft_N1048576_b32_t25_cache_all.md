# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 13211:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 952.608 | 51.847 | 5.36897e+08 | 5.20169e+08 | 2.14603e+09 | 1109.65 | 81.4273 | 2252.79 | 78.8209 | 50 | 47.13 | 0 | 702 | 38.95 | math_pipe_throttle | 22.37 | long_scoreboard | 20.9 | lg_throttle | 14.93 | 75.1176 | 82.1866 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 32 | t25 | all | 13211:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 884.736 | 48.153 | 5.36895e+08 | 5.20081e+08 | 2.15521e+09 | 1194.68 | 87.6664 | 2435.99 | 85.2309 | 50 | 47.98 | 83 | 3165 | 32.34 | long_scoreboard | 23.73 | lg_throttle | 19.54 | math_pipe_throttle | 17.5 | 80.8734 | 88.8703 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 2 | 1837.34 | 2.11404e+09 | 1.96885 | 0.99669 | 1.97539 | False | False | 2 | 2 | 1 | 1 | False | 1837.34 | 2.11404e+09 | 1.96885 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
