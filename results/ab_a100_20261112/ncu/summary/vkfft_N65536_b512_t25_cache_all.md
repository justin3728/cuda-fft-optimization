# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 22814:1:13:0 | VkFFT_main | (64, 512, 1) | (8, 16, 1) | 84 | 0 | 16384 | 16384 | 771.456 | 48.9046 | 5.36907e+08 | 5.20375e+08 | 2.1363e+09 | 1370.5 | 100.62 | 2769.18 | 103.02 | 31.25 | 29.72 | 27558 | 43851 | 49.38 | long_scoreboard | 51.42 | wait | 9.41 | barrier | 7.36 | 92.8483 | 98.6783 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |
| vkfft |  | 65536 | 512 | t25 | all | 22814:1:13:1 | VkFFT_main | (16, 512, 1) | (8, 64, 1) | 64 | 0 | 73728 | 73728 | 806.016 | 51.0954 | 5.36888e+08 | 5.20042e+08 | 2.16487e+09 | 1311.3 | 96.2732 | 2685.88 | 99.9209 | 50 | 48.29 | 838402 | 664903 | 30.91 | long_scoreboard | 23.54 | mio_throttle | 20.61 | barrier | 19.26 | 88.8379 | 95.71 | total_lts_bytes/read_plateau | False | False | 2 | 2 | 1 | 1 |

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 512 | t25 | all | 2 | 1577.47 | 2.11421e+09 | 1.96901 | 0.996683 | 1.97557 | False | False | 2 | 2 | 1 | 1 | False | 1577.47 | 2.11421e+09 | 1.96901 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
