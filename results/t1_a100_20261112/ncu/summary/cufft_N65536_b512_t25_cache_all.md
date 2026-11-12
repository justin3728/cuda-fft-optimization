# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 65536 | 512 | t25 | all | 7154:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 770.304 | 49.3947 | 5.36895e+08 | 5.19587e+08 | 2.13502e+09 | 1371.51 | 100.643 | 2771.66 | 96.9754 | 25 | 24.41 | 78707 | 90098 | 34 | long_scoreboard | 51.17 | mio_throttle | 12.78 | wait | 9.28 | 92.8448 | 101.116 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 65536 | 512 | t25 | all | 7154:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (16384, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 789.184 | 50.6053 | 5.36895e+08 | 5.20204e+08 | 2.13629e+09 | 1339.48 | 98.2924 | 2706.96 | 94.7116 | 25 | 24.06 | 135631 | 94752 | 24.44 | long_scoreboard | 54.56 | mio_throttle | 11.41 | barrier | 8.13 | 90.6758 | 98.7558 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 65536 | 512 | t25 | all | 2 | 1559.49 | 2.11358e+09 | 1.96843 | 0.99669 | 1.97496 | False | False | 2 | 2 | 1 | 1 | False | 1559.49 | 2.11358e+09 | 1.96843 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
