# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 6971:1:13:0 | VkFFT_main | (128, 1, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 52.512 | 59.6727 | 1.68403e+07 | 2.5033e+06 | 5.5201e+07 | 368.366 | 26.9832 | 1051.21 | 36.0688 | 12.5 | 12.03 | 0 | 0 | 42.19 | lg_throttle | 22.91 | wait | 18.72 | long_scoreboard | 16.28 | 25.2203 | 37.2443 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 1 | b1 | all | 6971:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 35.488 | 40.3273 | 1.68187e+07 | 2.38746e+06 | 5.71997e+07 | 541.201 | 39.6436 | 1611.8 | 55.3039 | 12.5 | 10.95 | 317044 | 272894 | 30.69 | long_scoreboard | 37.71 | wait | 15.39 | mio_throttle | 12.11 | 37.0591 | 57.1063 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 2 | 88 | 3.85498e+07 | 1.14887 | 0.996665 | 1.15272 | True | False | 2 | 2 | 1 | 1 | False | 88 | 3.85498e+07 | 1.14887 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
