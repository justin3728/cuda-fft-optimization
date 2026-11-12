# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 262144 | 1 | b1 | all | 14385:1:13:0 | transpose_opt | (16, 16, 1) | (32, 8, 1) | 44 | 16896 | 0 | 16896 | 19.232 | 9.27183 | 4.79206e+06 | 0 | 9.58522e+06 | 249.171 | 102.627 | 498.399 | 38.9589 | 83.33 | 61.82 | 1550 | 456 | 0 | long_scoreboard | 33.76 | long_scoreboard_pipe_l1tex | 33.76 | mio_throttle | 32.64 | 95.9017 | 34.2495 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 262144 | 1 | b1 | all | 14385:1:13:1 | fft_block_mixed_radix<256> | (512, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 54.72 | 26.3807 | 4.66752e+06 | 0 | 9.27907e+06 | 85.2982 | 35.1321 | 169.574 | 13.2552 | 33.33 | 31.45 | 163840 | 360448 | 64.97 | barrier | 40.56 | short_scoreboard | 16.64 | long_scoreboard | 15.77 | 32.8298 | 11.6529 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 262144 | 1 | b1 | all | 14385:1:13:2 | transpose_and_twiddle | (16, 16, 1) | (32, 8, 1) | 42 | 16896 | 0 | 16896 | 58.688 | 28.2937 | 4.79949e+06 | 0 | 1.26943e+07 | 81.7797 | 33.6829 | 216.301 | 16.9078 | 83.33 | 56.64 | 334 | 258 | 70.66 | short_scoreboard | 35.45 | tex_throttle | 26.33 | long_scoreboard | 13.12 | 31.4756 | 14.864 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 262144 | 1 | b1 | all | 14385:1:13:3 | fft_block_mixed_radix<256> | (512, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 54.624 | 26.3345 | 4.6432e+06 | 0 | 9.31997e+06 | 85.0029 | 35.0105 | 170.62 | 13.3371 | 33.33 | 31.51 | 163840 | 360448 | 65.01 | barrier | 40.58 | short_scoreboard | 16.64 | long_scoreboard | 15.94 | 32.7161 | 11.7249 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 262144 | 1 | b1 | all | 14385:1:13:4 | transpose_square_inplace | (16, 16, 1) | (32, 8, 1) | 64 | 33792 | 0 | 33792 | 20.16 | 9.71922 | 4.76915e+06 | 0 | 1.05073e+07 | 236.565 | 97.435 | 521.197 | 40.7409 | 33.33 | 31 | 1818 | 1158 | 0 | long_scoreboard | 63.5 | long_scoreboard_pipe_l1tex | 63.5 | barrier | 10.91 | 91.0498 | 35.8161 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 262144 | 1 | b1 | all | 5 | 207.424 | 2.36714e+07 | 2.82185 | 1.15165 | 2.45028 | True | False | 5 | 5 | 1 | 1 | False | 207.424 | 2.36714e+07 | 2.82185 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
