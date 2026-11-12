# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 23667:1:13:0 | VkFFT_main | (512, 1, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 170.56 | 58.83 | 6.71727e+07 | 5.68e+07 | 2.91359e+08 | 726.857 | 53.3211 | 1708.25 | 59.9033 | 25 | 23.86 | 22282 | 524288 | 39.8 | lg_throttle | 29.13 | math_pipe_throttle | 17.54 | long_scoreboard | 12.97 | 49.2301 | 62.3279 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 1 | b1 | all | 23667:1:13:1 | VkFFT_main | (1024, 1, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 119.36 | 41.17 | 6.71464e+07 | 5.27747e+07 | 2.80546e+08 | 1004.7 | 73.7032 | 2350.42 | 82.4224 | 25 | 23.45 | 40102 | 2.16312e+06 | 34.35 | long_scoreboard | 25.89 | mio_throttle | 22.38 | barrier | 11.22 | 68.0864 | 85.7585 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 2 | 289.92 | 2.43894e+08 | 1.81715 | 0.996675 | 1.82321 | False | False | 2 | 2 | 1 | 1 | False | 289.92 | 2.43894e+08 | 1.81715 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
