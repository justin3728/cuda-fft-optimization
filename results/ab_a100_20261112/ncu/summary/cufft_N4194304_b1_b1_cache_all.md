# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 1 | b1 | all | 28474:1:13:0 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (512, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 171.424 | 54.9154 | 6.71437e+07 | 5.27442e+07 | 2.75012e+08 | 699.365 | 51.346 | 1604.28 | 59.6828 | 50 | 46.73 | 0 | 1.57286e+06 | 30.5 | lg_throttle | 21.33 | long_scoreboard | 20.36 | math_pipe_throttle | 18.44 | 47.4527 | 57.1676 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 4194304 | 1 | b1 | all | 28474:1:13:1 | regular_fft_factor<2048, EPT<8>, 4, 1, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (512, 1, 1) | (4, 256, 1) | 60 | 0 | 65536 | 65536 | 140.736 | 45.0846 | 6.71452e+07 | 5.22794e+07 | 2.61306e+08 | 848.572 | 62.3005 | 1856.71 | 69.0738 | 50 | 48.04 | 0 | 1.57286e+06 | 29.13 | long_scoreboard | 24.17 | mio_throttle | 18.06 | math_pipe_throttle | 16.08 | 57.5802 | 66.1629 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 4194304 | 1 | b1 | all | 2 | 312.16 | 2.39313e+08 | 1.78302 | 0.996683 | 1.78895 | False | False | 2 | 2 | 1 | 1 | False | 312.16 | 2.39313e+08 | 1.78302 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
