# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 9706:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 401.344 | 33.5088 | 2.6846e+08 | 2.50858e+08 | 1.01347e+09 | 1293.95 | 94.7831 | 2525.19 | 86.644 | 25 | 24.09 | 38342 | 49178 | 32.85 | long_scoreboard | 53.43 | mio_throttle | 10.42 | wait | 8.94 | 87.6794 | 89.4677 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 9706:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 391.904 | 32.7206 | 2.68464e+08 | 2.51847e+08 | 1.06167e+09 | 1327.65 | 97.2519 | 2709.01 | 92.9509 | 25 | 24.48 | 43099 | 39714 | 33.44 | long_scoreboard | 49.44 | mio_throttle | 13.53 | wait | 9.01 | 89.9606 | 95.9802 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 9706:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 404.48 | 33.7706 | 2.6846e+08 | 2.5404e+08 | 1.062e+09 | 1291.78 | 94.6244 | 2625.59 | 90.0888 | 25 | 24.16 | 60354 | 50778 | 23.89 | long_scoreboard | 52.86 | mio_throttle | 11.92 | barrier | 8.11 | 87.5245 | 93.0248 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 3 | 1197.73 | 1.56213e+09 | 2.90969 | 0.996665 | 2.91943 | False | False | 3 | 3 | 1 | 1 | False | 1197.73 | 1.56213e+09 | 2.90969 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
