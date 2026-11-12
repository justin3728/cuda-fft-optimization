# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 28051:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 952.064 | 51.9214 | 5.36896e+08 | 5.20324e+08 | 2.14608e+09 | 1110.45 | 81.5271 | 2254.14 | 83.8589 | 50 | 47.17 | 0 | 390 | 38.77 | math_pipe_throttle | 22.05 | long_scoreboard | 20.9 | lg_throttle | 14.67 | 75.2304 | 80.3249 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 32 | t25 | all | 28051:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 1, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (4096, 1, 1) | (8, 128, 1) | 62 | 0 | 131072 | 131072 | 881.6 | 48.0786 | 5.36897e+08 | 5.20243e+08 | 2.15533e+09 | 1199.12 | 88.0367 | 2444.79 | 90.9518 | 50 | 47.73 | 106 | 1122 | 32.45 | long_scoreboard | 22.75 | lg_throttle | 19.59 | math_pipe_throttle | 17.47 | 81.2373 | 87.1189 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 32 | t25 | all | 2 | 1833.66 | 2.11436e+09 | 1.96915 | 0.996683 | 1.97571 | False | False | 2 | 2 | 1 | 1 | False | 1833.66 | 2.11436e+09 | 1.96915 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
