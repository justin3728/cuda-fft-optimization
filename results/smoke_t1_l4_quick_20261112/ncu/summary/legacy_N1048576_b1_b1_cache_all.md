# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 11530:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 44 | 16896 | 0 | 16896 | 68.928 | 9.55253 | 1.92346e+07 | 31232 | 3.88099e+07 | 279.506 | 115.105 | 563.05 | 44.0102 | 83.33 | 77.62 | 9348 | 2963 | 0 | mio_throttle | 32.22 | mio_throttle_pipe_mio | 32.22 | long_scoreboard | 26.02 | 107.591 | 37.8696 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 11530:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 201.568 | 27.9347 | 1.85274e+07 | 35712 | 4.07192e+07 | 92.0933 | 37.9254 | 202.012 | 15.7901 | 50 | 47.44 | 524288 | 1.44179e+06 | 79.54 | tex_throttle | 59.06 | barrier | 13.62 | short_scoreboard | 9.61 | 35.4503 | 13.5869 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 11530:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 42 | 16896 | 0 | 16896 | 180.288 | 24.9856 | 1.86067e+07 | 1920 | 5.03215e+07 | 103.216 | 42.5059 | 279.118 | 21.8169 | 83.33 | 74.97 | 1426 | 1582 | 81.1 | tex_throttle | 45.75 | short_scoreboard | 32.97 | barrier | 12.21 | 39.7277 | 18.7729 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 11530:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 201.088 | 27.8682 | 1.85325e+07 | 7680 | 4.06198e+07 | 92.1992 | 37.969 | 202 | 15.7891 | 50 | 47.29 | 524288 | 1.44179e+06 | 79.52 | tex_throttle | 59.48 | barrier | 13.68 | short_scoreboard | 9.59 | 35.488 | 13.5861 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 11530:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 64 | 33792 | 0 | 33792 | 69.696 | 9.65896 | 1.90276e+07 | 3328 | 4.12287e+07 | 273.056 | 112.448 | 591.551 | 46.2379 | 33.33 | 31.6 | 11182 | 4173 | 0 | long_scoreboard | 60.66 | long_scoreboard_pipe_l1tex | 60.66 | barrier | 13.2 | 105.099 | 39.7864 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 5 | 721.568 | 9.40086e+07 | 2.80167 | 1.1516 | 2.43286 | True | False | 5 | 5 | 1 | 1 | False | 721.568 | 9.40086e+07 | 2.80167 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
