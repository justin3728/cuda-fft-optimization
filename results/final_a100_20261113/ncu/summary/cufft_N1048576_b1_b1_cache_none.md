# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | none | 6768:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 51.744 | 49.6622 | 1.44905e+07 | 1.3147e+07 | 6.32331e+07 | 534.12 | 39.1249 | 1222.04 | 41.9303 | 50 | 44.82 | 0 | 0 | 33.68 | long_scoreboard | 23.36 | math_pipe_throttle | 20.27 | lg_throttle | 15.04 | 36.2004 | 43.2968 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 1 | b1 | none | 6768:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 52.448 | 50.3378 | 1.68079e+07 | 1.09788e+07 | 6.53395e+07 | 529.796 | 38.8082 | 1245.79 | 42.7455 | 50 | 48.35 | 6 | 58 | 26.1 | long_scoreboard | 24.55 | lg_throttle | 24.47 | math_pipe_throttle | 13.79 | 35.9924 | 44.1385 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | none | 2 | 104.192 | 5.54243e+07 | 1.65177 | 0.996665 | 1.6573 | True | False | 2 | 2 | 1 | 1 | False | 104.192 | 5.54243e+07 | 1.65177 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
