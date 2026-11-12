# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 1 | b1 | all | 5528:1:13:0 | VkFFT_main | (64, 1, 1) | (8, 16, 1) | 84 | 0 | 16384 | 16384 | 7.136 | 36.6174 | 1.06893e+06 | 0 | 3.81658e+06 | 149.794 | 10.9726 | 534.834 | 18.3511 | 31.25 | 6.21 | 0 | 0 | 23.62 | long_scoreboard | 24.34 | wait | 22.46 | imc_miss | 20.93 | 10.2943 | 18.9492 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 65536 | 1 | b1 | all | 5528:1:13:1 | VkFFT_main | (16, 1, 1) | (8, 64, 1) | 62 | 0 | 73728 | 73728 | 12.352 | 63.3826 | 1.06419e+06 | 0 | 3.64218e+06 | 86.1554 | 6.31098 | 294.865 | 10.1174 | 50 | 23.78 | 0 | 0 | 30.39 | math_pipe_throttle | 17.06 | mio_throttle | 15.64 | long_scoreboard | 14.08 | 5.92088 | 10.4471 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 1 | b1 | all | 2 | 19.488 | 2.13312e+06 | 1.01715 | 0.996665 | 1.02055 | True | False | 2 | 2 | 1 | 1 | False | 19.488 | 2.13312e+06 | 1.01715 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
