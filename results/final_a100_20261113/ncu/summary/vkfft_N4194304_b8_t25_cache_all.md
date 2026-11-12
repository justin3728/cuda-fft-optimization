# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 9276:1:13:0 | VkFFT_main | (512, 8, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 1153.57 | 57.7579 | 5.36955e+08 | 5.55477e+08 | 2.40481e+09 | 947.002 | 69.369 | 2084.67 | 71.5289 | 25 | 24.22 | 172383 | 4.1943e+06 | 42.6 | lg_throttle | 23.84 | math_pipe_throttle | 18.56 | long_scoreboard | 14.18 | 64.122 | 73.86 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 8 | t25 | all | 9276:1:13:1 | VkFFT_main | (1024, 8, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 843.68 | 42.2421 | 5.36909e+08 | 5.22428e+08 | 2.34505e+09 | 1255.61 | 91.9752 | 2779.55 | 95.3714 | 25 | 24.25 | 762394 | 1.74136e+07 | 36.26 | mio_throttle | 25.84 | long_scoreboard | 23.9 | barrier | 13.18 | 85.0567 | 98.4795 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 2 | 1997.25 | 2.15177e+09 | 2.00399 | 0.996665 | 2.0107 | False | False | 2 | 2 | 1 | 1 | False | 1997.25 | 2.15177e+09 | 2.00399 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
