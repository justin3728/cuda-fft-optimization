# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 23018:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 20.544 | 11.1516 | 1.67823e+07 | 2.6423e+06 | 6.14564e+07 | 945.514 | 69.4178 | 2991.45 | 111.289 | 100 | 71.37 | 17849 | 8055 | 0 | mio_throttle | 32.37 | lg_throttle | 26.04 | long_scoreboard | 18 | 64.7238 | 106.599 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 23018:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.904 | 32.5169 | 1.67994e+07 | 958720 | 6.33753e+07 | 296.442 | 21.7642 | 1057.95 | 39.358 | 37.5 | 35.02 | 526181 | 1.44392e+06 | 13.72 | mio_throttle | 33.61 | long_scoreboard | 18.6 | barrier | 16.34 | 20.3407 | 37.6994 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 23018:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 20.864 | 11.3253 | 1.67933e+07 | 2.4809e+06 | 5.95942e+07 | 923.804 | 67.8238 | 2856.32 | 106.261 | 100 | 77.87 | 18104 | 7081 | 37.19 | mio_throttle | 27.08 | lg_throttle | 14.21 | long_scoreboard | 13.96 | 63.2511 | 101.783 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 23018:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.68 | 32.3953 | 1.67992e+07 | 493824 | 6.37022e+07 | 289.763 | 21.2738 | 1067.4 | 39.7095 | 37.5 | 35.21 | 526006 | 1.44374e+06 | 13.82 | mio_throttle | 34.27 | long_scoreboard | 18.33 | barrier | 15.96 | 19.897 | 38.0361 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 23018:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 23.232 | 12.6107 | 1.67814e+07 | 605568 | 6.3377e+07 | 748.408 | 54.9466 | 2728 | 101.488 | 50 | 39.64 | 13804 | 6234 | 0 | mio_throttle | 29.69 | lg_throttle | 25.74 | long_scoreboard | 24.59 | 51.3813 | 97.2109 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 5 | 184.224 | 9.1137e+07 | 2.71609 | 0.996683 | 2.72513 | True | False | 5 | 5 | 1 | 1 | False | 184.224 | 9.1137e+07 | 2.71609 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
