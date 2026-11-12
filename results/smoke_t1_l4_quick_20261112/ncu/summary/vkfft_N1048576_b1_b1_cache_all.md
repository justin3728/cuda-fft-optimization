# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 12518:1:13:0 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 254 | 0 | 65536 | 65536 | 335.392 | 54.5062 | 3.95049e+07 | 2.21888e+06 | 5.12079e+07 | 124.403 | 51.231 | 152.681 | 11.9341 | 8.33 | 8.13 | 0 | 131072 | 64.8 | tex_throttle | 45.82 | short_scoreboard | 23.27 | lg_throttle | 13.85 | 48.028 | 10.269 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 1 | b1 | all | 12518:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 279.936 | 45.4938 | 1.86903e+07 | 16256 | 3.44734e+07 | 66.8244 | 27.5193 | 123.147 | 9.62567 | 8.33 | 8.36 | 294289 | 265312 | 70.84 | short_scoreboard | 42.87 | tex_throttle | 33.37 | long_scoreboard | 13.6 | 25.7217 | 8.28263 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 2 | 615.328 | 6.04303e+07 | 1.80096 | 1.1516 | 1.56388 | True | False | 2 | 2 | 1 | 1 | False | 615.328 | 6.04303e+07 | 1.80096 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
