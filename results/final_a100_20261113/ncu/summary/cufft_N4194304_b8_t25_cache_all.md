# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 9073:1:13:0 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 1105.82 | 55.4296 | 5.36908e+08 | 5.22741e+08 | 2.31223e+09 | 958.243 | 70.1924 | 2090.95 | 71.7444 | 50 | 48.81 | 0 | 1.25829e+07 | 34.56 | math_pipe_throttle | 20.44 | lg_throttle | 20.11 | long_scoreboard | 18.87 | 64.9121 | 74.0825 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 4194304 | 8 | t25 | all | 9073:1:13:1 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 889.184 | 44.5704 | 5.3691e+08 | 5.2205e+08 | 2.1859e+09 | 1190.93 | 87.2373 | 2458.32 | 84.3493 | 50 | 48.49 | 0 | 1.25829e+07 | 33.63 | mio_throttle | 20.58 | long_scoreboard | 19.06 | math_pipe_throttle | 18.27 | 80.6755 | 87.0982 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 8 | t25 | all | 2 | 1995.01 | 2.11861e+09 | 1.97311 | 0.996665 | 1.97971 | False | False | 2 | 2 | 1 | 1 | False | 1995.01 | 2.11861e+09 | 1.97311 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
