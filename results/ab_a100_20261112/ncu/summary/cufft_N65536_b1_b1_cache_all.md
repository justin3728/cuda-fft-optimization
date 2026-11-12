# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 65536 | 1 | b1 | all | 18820:1:13:0 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (32, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 7.808 | 49.7959 | 1.07123e+06 | 0 | 3.68762e+06 | 137.197 | 10.0727 | 472.287 | 17.5701 | 25 | 6.26 | 0 | 0 | 27.86 | wait | 28.83 | long_scoreboard | 28.14 | imc_miss | 19.18 | 9.4286 | 16.8297 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 65536 | 1 | b1 | all | 18820:1:13:1 | regular_fft_factor<256, EPT<16>, 8, 4, 14, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (32, 1, 1) | (8, 16, 1) | 120 | 0 | 32768 | 32768 | 7.872 | 50.2041 | 1.0711e+06 | 0 | 3.75712e+06 | 136.065 | 9.98963 | 477.276 | 17.7557 | 25 | 6.18 | 0 | 0 | 20.38 | long_scoreboard | 37.68 | wait | 20.89 | imc_miss | 15.49 | 9.35083 | 17.0075 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 65536 | 1 | b1 | all | 2 | 15.68 | 2.14234e+06 | 1.02155 | 0.996683 | 1.02495 | True | False | 2 | 2 | 1 | 1 | False | 15.68 | 2.14234e+06 | 1.02155 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
