# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 1 | b1 | all | 8437:1:13:0 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (512, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 170.784 | 54.8566 | 6.71404e+07 | 5.26975e+07 | 2.78611e+08 | 701.692 | 51.3998 | 1631.36 | 55.975 | 50 | 47.73 | 0 | 1.57286e+06 | 30.59 | lg_throttle | 21.45 | long_scoreboard | 20.84 | math_pipe_throttle | 18.11 | 47.608 | 57.7992 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 4194304 | 1 | b1 | all | 8437:1:13:1 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (512, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 140.544 | 45.1434 | 6.71436e+07 | 5.2303e+07 | 2.61819e+08 | 849.887 | 62.2552 | 1862.9 | 63.9194 | 50 | 47.58 | 0 | 1.57286e+06 | 28.9 | long_scoreboard | 24.15 | mio_throttle | 17.81 | math_pipe_throttle | 15.92 | 57.6658 | 66.0026 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 1 | b1 | all | 2 | 311.328 | 2.39284e+08 | 1.78281 | 0.996665 | 1.78877 | False | False | 2 | 2 | 1 | 1 | False | 311.328 | 2.39284e+08 | 1.78281 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
