# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | all | 12177:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | 0 | 65536 | 65536 | 410.912 | 54.9583 | 1.99186e+07 | 256 | 3.43276e+07 | 48.4747 | 19.9626 | 83.54 | 6.52981 | 66.67 | 65.78 | 0 | 131072 | 74.44 | tex_throttle | 74.47 | lg_throttle | 9.63 | long_scoreboard | 5.65 | 18.6578 | 5.61872 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| cufft |  | 1048576 | 1 | b1 | all | 12177:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | 0 | 65536 | 65536 | 336.768 | 45.0417 | 2.10339e+07 | 128 | 3.43437e+07 | 62.4584 | 25.7213 | 101.98 | 7.97117 | 66.67 | 65.81 | 0 | 131072 | 69.12 | tex_throttle | 70.47 | lg_throttle | 14.52 | long_scoreboard | 5.83 | 24.04 | 6.85898 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft |  | 1048576 | 1 | b1 | all | 2 | 747.68 | 4.09528e+07 | 1.22049 | 1.1516 | 1.05982 | True | False | 2 | 2 | 1 | 1 | False | 747.68 | 4.09528e+07 | 1.22049 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
