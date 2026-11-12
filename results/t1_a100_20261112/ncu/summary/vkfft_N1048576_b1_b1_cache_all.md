# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 8998:1:13:0 | VkFFT_main | (128, 1, 1) | (8, 32, 1) | 228 | 0 | 131072 | 131072 | 52.544 | 59.7091 | 1.6841e+07 | 2.48512e+06 | 5.49693e+07 | 367.808 | 26.99 | 1046.16 | 36.6031 | 12.5 | 11.91 | 0 | 0 | 42.12 | lg_throttle | 23.49 | wait | 18.86 | long_scoreboard | 15.37 | 25.1744 | 38.1661 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 1048576 | 1 | b1 | all | 8998:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | 0 | 81920 | 81920 | 35.456 | 40.2909 | 1.68192e+07 | 2.37402e+06 | 5.72402e+07 | 541.325 | 39.7228 | 1614.4 | 56.4849 | 12.5 | 10.94 | 317309 | 272510 | 30.76 | long_scoreboard | 37.63 | wait | 15.59 | mio_throttle | 12.52 | 37.0562 | 58.8968 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 1048576 | 1 | b1 | all | 2 | 88 | 3.85193e+07 | 1.14796 | 0.99669 | 1.15178 | True | False | 2 | 2 | 1 | 1 | False | 88 | 3.85193e+07 | 1.14796 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
