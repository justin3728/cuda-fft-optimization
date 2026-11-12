# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 29883:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 812.288 | 33.4312 | 5.36895e+08 | 5.1915e+08 | 1.98279e+09 | 1300.09 | 95.4498 | 2440.99 | 90.8103 | 25 | 24.29 | 71754 | 130601 | 32.32 | long_scoreboard | 53.07 | mio_throttle | 10.79 | wait | 8.8 | 88.0792 | 86.9834 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 29883:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 800.832 | 32.9597 | 5.36895e+08 | 5.20803e+08 | 2.13453e+09 | 1320.75 | 96.9668 | 2665.39 | 99.1584 | 25 | 24.24 | 104440 | 86369 | 32.59 | long_scoreboard | 48.59 | mio_throttle | 12.86 | wait | 10.19 | 89.477 | 94.9796 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 29883:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 816.608 | 33.609 | 5.36895e+08 | 5.20788e+08 | 2.13625e+09 | 1295.21 | 95.0921 | 2616 | 97.3211 | 25 | 24.36 | 111333 | 109406 | 23.67 | long_scoreboard | 52.16 | mio_throttle | 12.66 | barrier | 8.48 | 87.7471 | 93.2198 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 3 | 2429.73 | 3.17143e+09 | 2.95362 | 0.996683 | 2.96345 | False | False | 3 | 3 | 1 | 1 | False | 2429.73 | 3.17143e+09 | 2.95362 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
