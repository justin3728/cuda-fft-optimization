# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 9978:1:13:0 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 401.504 | 32.9326 | 2.6847e+08 | 2.51855e+08 | 1.05912e+09 | 1295.94 | 94.929 | 2637.87 | 90.5101 | 25 | 24.13 | 39277 | 40926 | 50.32 | long_scoreboard | 31.94 | barrier | 12.38 | wait | 11.57 | 87.8118 | 93.4598 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 9978:1:13:1 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 128 | 0 | 32768 | 32768 | 386.848 | 31.7305 | 2.6847e+08 | 2.51036e+08 | 1.00019e+09 | 1342.92 | 98.3703 | 2585.48 | 88.7123 | 25 | 24 | 32974 | 35617 | 52.35 | long_scoreboard | 33.89 | wait | 12.04 | barrier | 10.84 | 90.9973 | 91.6035 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |
| vkfft |  | 16777216 | 1 | b1 | all | 9978:1:13:2 | VkFFT_main | (8192, 1, 1) | (8, 16, 1) | 100 | 0 | 36864 | 36864 | 430.816 | 35.3369 | 2.68457e+08 | 2.52504e+08 | 1.06336e+09 | 1209.24 | 88.5784 | 2468.24 | 84.6898 | 25 | 24.36 | 122129 | 291838 | 25.72 | long_scoreboard | 50.08 | mio_throttle | 11.9 | barrier | 11.57 | 81.9357 | 87.4499 | total_lts_bytes/read_plateau | False | False | 3 | 3 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 3 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 16777216 | 1 | b1 | all | 3 | 1219.17 | 1.56079e+09 | 2.9072 | 0.996665 | 2.91693 | False | False | 3 | 3 | 1 | 1 | False | 1219.17 | 1.56079e+09 | 2.9072 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 3; captured launch count: 3; expected execution launches: 3.
