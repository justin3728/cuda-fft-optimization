# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | none | 7177:1:13:0 | VkFFT_main | (128, 1, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 55.84 | 58.3807 | 1.55532e+07 | 1.27972e+07 | 6.33748e+07 | 507.707 | 37.1901 | 1134.94 | 38.9417 | 12.5 | 11.31 | 0 | 0 | 38.99 | lg_throttle | 23.33 | wait | 18.27 | long_scoreboard | 17.85 | 34.4348 | 40.2108 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 1 | b1 | none | 7177:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 39.808 | 41.6193 | 1.68201e+07 | 1.11747e+07 | 6.73415e+07 | 703.244 | 51.5134 | 1691.66 | 58.0438 | 12.5 | 11.11 | 319275 | 269318 | 26.98 | long_scoreboard | 48.11 | wait | 13.24 | mio_throttle | 9.8 | 47.7702 | 59.9355 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | none | 2 | 95.648 | 5.63451e+07 | 1.67921 | 0.996665 | 1.68483 | True | False | 2 | 2 | 1 | 1 | False | 95.648 | 5.63451e+07 | 1.67921 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
