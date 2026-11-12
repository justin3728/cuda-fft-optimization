# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 14048:1:13:0 | VkFFT_main | (512, 1, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 168.8 | 58.8006 | 6.7175e+07 | 5.69097e+07 | 2.95617e+08 | 735.099 | 53.9421 | 1751.29 | 61.2743 | 25 | 23.94 | 21976 | 524288 | 39.99 | lg_throttle | 28.76 | math_pipe_throttle | 18.06 | long_scoreboard | 13.22 | 49.813 | 63.8908 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 1 | b1 | all | 14048:1:13:1 | VkFFT_main | (1024, 1, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 118.272 | 41.1994 | 6.71459e+07 | 5.28252e+07 | 2.80298e+08 | 1014.37 | 74.4349 | 2369.94 | 82.9198 | 25 | 23.72 | 42709 | 2.16577e+06 | 34.68 | long_scoreboard | 26.05 | mio_throttle | 22.38 | barrier | 11.15 | 68.7754 | 86.4605 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 1 | b1 | all | 2 | 287.072 | 2.44056e+08 | 1.81836 | 0.99669 | 1.8244 | False | False | 2 | 2 | 1 | 1 | False | 287.072 | 2.44056e+08 | 1.81836 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
