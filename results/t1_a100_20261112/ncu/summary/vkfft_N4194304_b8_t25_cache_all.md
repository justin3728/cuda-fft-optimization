# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 14679:1:13:0 | VkFFT_main | (512, 8, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 1139.49 | 57.3876 | 5.36944e+08 | 5.54924e+08 | 2.40472e+09 | 958.209 | 70.3141 | 2110.35 | 73.8374 | 25 | 24.2 | 174296 | 4.1943e+06 | 43.24 | lg_throttle | 23.75 | math_pipe_throttle | 18.85 | long_scoreboard | 14.08 | 64.8336 | 76.9902 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 8 | t25 | all | 14679:1:13:1 | VkFFT_main | (1024, 8, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 846.112 | 42.6124 | 5.36909e+08 | 5.22434e+08 | 2.34256e+09 | 1252.01 | 91.8736 | 2768.62 | 96.869 | 25 | 24.19 | 762259 | 1.7438e+07 | 36.24 | mio_throttle | 25.79 | long_scoreboard | 23.67 | barrier | 13.16 | 84.7517 | 101.005 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 2 | 1985.6 | 2.15121e+09 | 2.00347 | 0.99669 | 2.01012 | False | False | 2 | 2 | 1 | 1 | False | 1985.6 | 2.15121e+09 | 2.00347 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
