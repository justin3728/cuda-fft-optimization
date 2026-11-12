# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 8182:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 22.56 | 12.2353 | 1.67835e+07 | 9.44026e+06 | 7.27726e+07 | 1162.4 | 85.2978 | 3225.74 | 112.863 | 100 | 75.31 | 19335 | 5764 | 0 | mio_throttle | 32.9 | lg_throttle | 24.79 | long_scoreboard | 22.07 | 79.005 | 117.682 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 8182:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.656 | 31.8119 | 2.84403e+06 | 2.83661e+06 | 6.18028e+07 | 96.8467 | 7.10669 | 1053.65 | 36.8652 | 37.5 | 34.66 | 526308 | 1.44408e+06 | 14.13 | mio_throttle | 38.85 | barrier | 16.48 | lg_throttle | 12.7 | 6.55455 | 38.4393 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 8182:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 25.472 | 13.8146 | 1.67936e+07 | 1.00963e+07 | 7.07635e+07 | 1055.66 | 77.4654 | 2778.09 | 97.2002 | 100 | 83.93 | 17716 | 4709 | 29.3 | mio_throttle | 31.25 | long_scoreboard | 17.77 | lg_throttle | 15.19 | 71.7167 | 101.351 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 8182:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 58.208 | 31.5689 | 2.19968e+06 | 2.25306e+06 | 6.20519e+07 | 76.497 | 5.61341 | 1066.04 | 37.2987 | 37.5 | 34.62 | 526344 | 1.44416e+06 | 14.11 | mio_throttle | 39.53 | barrier | 16.23 | lg_throttle | 12.5 | 5.17624 | 38.8913 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 8182:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 19.488 | 10.5692 | 2.31437e+06 | 2.8e+06 | 6.13935e+07 | 262.437 | 19.2578 | 3150.32 | 110.224 | 50 | 35.28 | 13090 | 12638 | 0 | mio_throttle | 29.34 | lg_throttle | 28.32 | long_scoreboard | 16.46 | 17.7356 | 114.931 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 5 | 184.384 | 6.83613e+07 | 2.03733 | 0.99669 | 2.04409 | True | False | 5 | 5 | 1 | 1 | False | 184.384 | 6.83613e+07 | 2.03733 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
