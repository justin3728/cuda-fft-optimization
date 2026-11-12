# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 23877:1:13:0 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 1139.17 | 56.0747 | 5.36923e+08 | 5.2232e+08 | 2.30151e+09 | 929.839 | 68.2115 | 2020.34 | 70.8474 | 50 | 47.15 | 0 | 1.25829e+07 | 33.7 | math_pipe_throttle | 20.09 | lg_throttle | 19.1 | long_scoreboard | 18.34 | 62.9103 | 73.715 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 4194304 | 8 | t25 | all | 23877:1:13:1 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 892.352 | 43.9253 | 5.3691e+08 | 5.2195e+08 | 2.1828e+09 | 1186.59 | 87.0467 | 2446.12 | 85.7785 | 50 | 48.16 | 0 | 1.25829e+07 | 33.64 | mio_throttle | 20.64 | long_scoreboard | 18.72 | math_pipe_throttle | 18.34 | 80.2821 | 89.2504 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 2 | 2031.52 | 2.1181e+09 | 1.97264 | 0.996675 | 1.97922 | False | False | 2 | 2 | 1 | 1 | False | 2031.52 | 2.1181e+09 | 1.97264 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
