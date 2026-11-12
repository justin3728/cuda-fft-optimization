# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 10482:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 816.16 | 33.4848 | 5.36911e+08 | 5.19167e+08 | 2.0005e+09 | 1293.96 | 94.7841 | 2451.12 | 84.1022 | 25 | 24.19 | 80387 | 128480 | 32.09 | long_scoreboard | 50.54 | mio_throttle | 12.24 | wait | 8.7 | 87.6583 | 86.8431 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 10482:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 808.448 | 33.1683 | 5.36895e+08 | 5.20951e+08 | 2.13481e+09 | 1308.49 | 95.8484 | 2640.62 | 90.6045 | 25 | 24.38 | 108514 | 97341 | 32.42 | long_scoreboard | 48.06 | mio_throttle | 13.71 | wait | 10.14 | 88.6403 | 93.5573 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 10482:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 812.8 | 33.3469 | 5.36895e+08 | 5.20606e+08 | 2.13604e+09 | 1301.06 | 95.3041 | 2628 | 90.1715 | 25 | 24.29 | 118504 | 110795 | 23.65 | long_scoreboard | 51.97 | mio_throttle | 12.36 | barrier | 8.14 | 88.1374 | 93.1102 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 3 | 2437.41 | 3.17143e+09 | 2.95362 | 0.996665 | 2.9635 | False | False | 3 | 3 | 1 | 1 | False | 2437.41 | 3.17143e+09 | 2.95362 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
