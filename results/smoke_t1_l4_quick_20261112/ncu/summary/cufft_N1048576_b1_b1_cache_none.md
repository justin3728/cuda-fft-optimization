# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | none | 12349:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | 0 | 65536 | 65536 | 384.128 | 55.1401 | 256 | 135680 | 3.42968e+07 | 0.353882 | 0.145734 | 89.2848 | 6.97884 | 66.67 | 65.68 | 0 | 131072 | 83.1 | tex_throttle | 87.27 | short_scoreboard | 3.04 | barrier | 2.53 | 0.143989 | 6.00511 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 1 | b1 | none | 12349:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | 0 | 65536 | 65536 | 312.512 | 44.8599 | 9.86394e+06 | 1.41491e+06 | 3.4326e+07 | 36.0909 | 14.8628 | 109.839 | 8.58543 | 66.67 | 63.54 | 0 | 131072 | 77.05 | tex_throttle | 84.46 | lg_throttle | 3.73 | barrier | 3.33 | 13.991 | 7.38753 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | none | 2 | 696.64 | 1.14148e+07 | 0.340187 | 1.1516 | 0.295404 | True | False | 2 | 2 | 1 | 1 | False | 696.64 | 1.14148e+07 | 0.340187 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
