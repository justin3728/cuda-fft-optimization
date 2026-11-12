# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 7365:1:13:0 | VkFFT_main | (64, 512, 1) | (8, 16, 1) | 84 | 0 | 16384 | 16384 | 770.624 | 49.0688 | 5.36894e+08 | 5.20508e+08 | 2.13548e+09 | 1372.14 | 100.688 | 2771.1 | 96.9556 | 31.25 | 29.99 | 27293 | 44334 | 49.58 | long_scoreboard | 49.18 | wait | 9.41 | barrier | 7.2 | 92.8858 | 101.096 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 65536 | 512 | t25 | all | 7365:1:13:1 | VkFFT_main | (16, 512, 1) | (8, 64, 1) | 64 | 0 | 73728 | 73728 | 799.872 | 50.9312 | 5.36888e+08 | 5.19922e+08 | 2.16481e+09 | 1321.22 | 96.9524 | 2706.45 | 94.6935 | 50 | 48.34 | 834316 | 665159 | 31.06 | long_scoreboard | 23.28 | mio_throttle | 20.38 | barrier | 19.17 | 89.44 | 98.7369 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 2 | 1570.5 | 2.11421e+09 | 1.96901 | 0.99669 | 1.97555 | False | False | 2 | 2 | 1 | 1 | False | 1570.5 | 2.11421e+09 | 1.96901 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
