# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 24223:1:13:0 | VkFFT_main | (128, 1, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 54.016 | 60.1997 | 1.68407e+07 | 2.51264e+06 | 5.50052e+07 | 358.289 | 26.3049 | 1018.31 | 37.8835 | 12.5 | 11.96 | 0 | 0 | 41.99 | lg_throttle | 22.33 | wait | 18.55 | long_scoreboard | 15.74 | 24.5306 | 36.287 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 1 | b1 | all | 24223:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 35.712 | 39.8003 | 1.68188e+07 | 2.39053e+06 | 5.70707e+07 | 537.896 | 39.4913 | 1598.08 | 59.4522 | 12.5 | 10.96 | 316785 | 273047 | 30.77 | long_scoreboard | 37.43 | wait | 15.36 | mio_throttle | 12.08 | 36.8333 | 56.9468 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 2 | 89.728 | 3.85627e+07 | 1.14926 | 0.996683 | 1.15308 | True | False | 2 | 2 | 1 | 1 | False | 89.728 | 3.85627e+07 | 1.14926 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
