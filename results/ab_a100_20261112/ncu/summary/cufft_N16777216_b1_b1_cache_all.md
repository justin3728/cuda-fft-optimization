# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 29324:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 399.232 | 33.1888 | 2.68459e+08 | 2.50824e+08 | 1.00966e+09 | 1300.71 | 95.4953 | 2529 | 94.0845 | 25 | 24.16 | 47358 | 42405 | 33.11 | long_scoreboard | 48.66 | mio_throttle | 14.67 | wait | 9.01 | 88.1434 | 90.1196 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 29324:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 396.768 | 32.984 | 2.68459e+08 | 2.51814e+08 | 1.06163e+09 | 1311.28 | 96.2715 | 2675.7 | 99.5418 | 25 | 24.22 | 47170 | 39697 | 33.22 | long_scoreboard | 49.18 | mio_throttle | 14.29 | wait | 9.13 | 88.8572 | 95.3469 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| cufft |  | 16777216 | 1 | b1 | all | 29324:1:13:2 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (8192, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 406.912 | 33.8272 | 2.68473e+08 | 2.54089e+08 | 1.06185e+09 | 1284.21 | 94.2844 | 2609.54 | 97.0808 | 25 | 24.22 | 58703 | 52146 | 23.97 | long_scoreboard | 51.2 | mio_throttle | 13.13 | barrier | 8.01 | 87.0174 | 92.9896 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 16777216 | 1 | b1 | all | 3 | 1202.91 | 1.56212e+09 | 2.90967 | 0.996683 | 2.91936 | False | False | 3 | 3 | 1 | 1 | False | 1202.91 | 1.56212e+09 | 2.90967 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
