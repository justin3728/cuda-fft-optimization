# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 262144 | 1 | b1 | all | 14877:1:13:0 | VkFFT_main | (64, 1, 1) | (8, 64, 1) | 64 | 0 | 65536 | 65536 | 110.144 | 51.0607 | 9.88352e+06 | 0 | 1.29267e+07 | 89.7327 | 36.9586 | 117.362 | 9.17395 | 33.33 | 32.71 | 0 | 0 | 67.53 | tex_throttle | 59.03 | long_scoreboard | 11.19 | long_scoreboard_pipe_l1tex | 11.19 | 34.5366 | 8.065 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 262144 | 1 | b1 | all | 14877:1:13:1 | VkFFT_main | (64, 1, 1) | (8, 64, 1) | 62 | 0 | 73728 | 73728 | 105.568 | 48.9393 | 4.72602e+06 | 0 | 8.74742e+06 | 44.7675 | 18.4386 | 82.8606 | 6.47704 | 33.33 | 33.16 | 834 | 345 | 61.71 | tex_throttle | 61.47 | long_scoreboard | 13.84 | long_scoreboard_pipe_l1tex | 13.84 | 17.2302 | 5.6941 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 262144 | 1 | b1 | all | 2 | 215.712 | 1.46095e+07 | 1.74159 | 1.15165 | 1.51226 | True | False | 2 | 2 | 1 | 1 | False | 215.712 | 1.46095e+07 | 1.74159 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
