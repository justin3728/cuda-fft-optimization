# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 262144 | 1 | b1 | all | 14708:1:13:0 | regular_fft_factor<512, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (64, 1, 1) | (8, 64, 1) | 62 | 0 | 32768 | 32768 | 120.768 | 56.0773 | 4.92608e+06 | 0 | 8.68854e+06 | 40.7896 | 16.8002 | 71.9441 | 5.62373 | 66.67 | 36.31 | 0 | 32768 | 68.41 | tex_throttle | 59.17 | long_scoreboard | 13.91 | long_scoreboard_pipe_l1tex | 13.91 | 15.6992 | 4.94393 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 262144 | 1 | b1 | all | 14708:1:13:1 | regular_fft_factor<512, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (64, 1, 1) | (8, 64, 1) | 62 | 0 | 32768 | 32768 | 94.592 | 43.9227 | 5.088e+06 | 0 | 8.68934e+06 | 53.7889 | 22.1543 | 91.8613 | 7.18061 | 66.67 | 36.6 | 0 | 32768 | 62.68 | tex_throttle | 55.82 | long_scoreboard | 14.72 | long_scoreboard_pipe_l1tex | 14.72 | 20.7024 | 6.31262 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 262144 | 1 | b1 | all | 2 | 215.36 | 1.00141e+07 | 1.19377 | 1.15165 | 1.03658 | True | False | 2 | 2 | 1 | 1 | False | 215.36 | 1.00141e+07 | 1.19377 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
