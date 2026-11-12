# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 15860:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 819.008 | 33.584 | 5.36895e+08 | 5.19058e+08 | 1.98287e+09 | 1289.31 | 94.6103 | 2421.06 | 84.7085 | 25 | 24.22 | 72692 | 147102 | 32.13 | long_scoreboard | 52.36 | mio_throttle | 10.66 | wait | 8.72 | 87.2805 | 88.3255 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 15860:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 807.648 | 33.1181 | 5.36938e+08 | 5.20824e+08 | 2.1352e+09 | 1309.68 | 96.1055 | 2643.73 | 92.499 | 25 | 24.26 | 103605 | 99448 | 32.47 | long_scoreboard | 47.93 | mio_throttle | 13.53 | wait | 10.13 | 88.6576 | 96.4488 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 2 | t25 | all | 15860:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 812.032 | 33.2979 | 5.36895e+08 | 5.20519e+08 | 2.13592e+09 | 1302.18 | 95.5551 | 2630.34 | 92.0306 | 25 | 24.29 | 121214 | 110694 | 23.68 | long_scoreboard | 52.08 | mio_throttle | 12.7 | barrier | 8.32 | 88.1502 | 95.9603 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 2 | t25 | all | 3 | 2438.69 | 3.17113e+09 | 2.95334 | 0.99669 | 2.96315 | False | False | 3 | 3 | 1 | 1 | False | 2438.69 | 3.17113e+09 | 2.95334 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
