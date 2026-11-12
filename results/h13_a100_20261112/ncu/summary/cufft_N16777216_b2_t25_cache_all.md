# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 24845:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 820.864 | 33.5088 | 5.36895e+08 | 5.19094e+08 | 1.99492e+09 | 1286.44 | 94.3709 | 2430.27 | 85.2226 | 25 | 24.36 | 74308 | 135571 | 32 | long_scoreboard | 52.59 | mio_throttle | 10.71 | wait | 8.69 | 87.0408 | 88.672 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 24845:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 815.84 | 33.3037 | 5.36911e+08 | 5.21014e+08 | 2.13448e+09 | 1296.73 | 95.1261 | 2616.29 | 91.7458 | 25 | 24.21 | 110336 | 109637 | 32.22 | long_scoreboard | 48.04 | mio_throttle | 13.5 | wait | 10.09 | 87.7348 | 95.4593 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 24845:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 812.992 | 33.1875 | 5.36895e+08 | 5.20394e+08 | 2.13584e+09 | 1300.49 | 95.402 | 2627.14 | 92.126 | 25 | 24.28 | 116065 | 107899 | 23.66 | long_scoreboard | 52.47 | mio_throttle | 12.85 | barrier | 8.04 | 87.9901 | 95.8549 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 3 | 2449.7 | 3.1712e+09 | 2.95341 | 0.996675 | 2.96327 | False | False | 3 | 3 | 1 | 1 | False | 2449.7 | 3.1712e+09 | 2.95341 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
