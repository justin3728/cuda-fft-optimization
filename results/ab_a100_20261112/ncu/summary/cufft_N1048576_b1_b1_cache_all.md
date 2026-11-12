# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | all | 23818:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 48.736 | 50.8514 | 1.67999e+07 | 2.35034e+06 | 5.50814e+07 | 392.938 | 28.8487 | 1130.2 | 42.0459 | 50 | 47.01 | 0 | 0 | 36.03 | long_scoreboard | 22.47 | math_pipe_throttle | 21.54 | lg_throttle | 15.64 | 26.9083 | 40.274 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 1 | b1 | all | 23818:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 47.104 | 49.1486 | 1.68003e+07 | 2.3255e+06 | 5.59365e+07 | 406.033 | 29.8101 | 1187.51 | 44.1781 | 50 | 47.52 | 0 | 1 | 29.6 | lg_throttle | 22.74 | long_scoreboard | 21.04 | math_pipe_throttle | 16.19 | 27.806 | 42.3163 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | all | 2 | 95.84 | 3.8276e+07 | 1.14071 | 0.996683 | 1.14451 | True | False | 2 | 2 | 1 | 1 | False | 95.84 | 3.8276e+07 | 1.14071 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
