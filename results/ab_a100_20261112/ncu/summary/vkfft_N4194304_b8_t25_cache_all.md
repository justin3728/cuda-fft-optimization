# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 29105:1:13:0 | VkFFT_main | (512, 8, 1) | (4, 128, 1) | 128 | 0 | 131072 | 131072 | 1171.3 | 58.0945 | 5.36943e+08 | 5.5636e+08 | 2.40862e+09 | 933.413 | 68.5294 | 2056.37 | 76.5016 | 25 | 23.66 | 172531 | 4.1943e+06 | 41.9 | lg_throttle | 23.28 | math_pipe_throttle | 18.41 | long_scoreboard | 13.83 | 63.2056 | 73.2776 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 4194304 | 8 | t25 | all | 29105:1:13:1 | VkFFT_main | (1024, 8, 1) | (2, 128, 1) | 124 | 0 | 65536 | 65536 | 844.896 | 41.9055 | 5.36909e+08 | 5.2243e+08 | 2.34818e+09 | 1253.81 | 92.0522 | 2779.25 | 103.394 | 25 | 24.23 | 760136 | 1.74305e+07 | 36.3 | mio_throttle | 25.83 | long_scoreboard | 23.82 | barrier | 13.18 | 84.9401 | 99.037 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 4194304 | 8 | t25 | all | 2 | 2016.19 | 2.15264e+09 | 2.0048 | 0.996683 | 2.01148 | False | False | 2 | 2 | 1 | 1 | False | 2016.19 | 2.15264e+09 | 2.0048 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
