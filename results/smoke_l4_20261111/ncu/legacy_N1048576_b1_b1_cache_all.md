# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy | 1048576 | 1 | b1 | all | 1577:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 44 | NA | NA | NA | 68.928 | 9.53055 | 1.92402e+07 | 12544 | 3.88412e+07 | 279.317 | 115.065 | 563.505 | 44.0215 | 83.33 | 77.26 | 9144 | 2986 | 0 | mio_throttle | 32.13 | mio_throttle_pipe_mio | 32.13 | long_scoreboard | 25.9 |
| legacy | 1048576 | 1 | b1 | all | 1577:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | NA | NA | NA | 202.656 | 28.0209 | 1.85079e+07 | 52096 | 4.07198e+07 | 91.5838 | 37.7281 | 200.931 | 15.6969 | 50 | 47.31 | 524288 | 1.44179e+06 | 79.27 | tex_throttle | 59.02 | barrier | 13.46 | short_scoreboard | 9.58 |
| legacy | 1048576 | 1 | b1 | all | 1577:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 42 | NA | NA | NA | 180.768 | 24.9945 | 1.86095e+07 | 896 | 5.02919e+07 | 102.952 | 42.4112 | 278.212 | 21.7342 | 83.33 | 75.04 | 1429 | 1467 | 81.15 | tex_throttle | 44.84 | short_scoreboard | 33.05 | barrier | 11.39 |
| legacy | 1048576 | 1 | b1 | all | 1577:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | NA | NA | NA | 201.76 | 27.897 | 1.8528e+07 | 13184 | 4.08557e+07 | 91.8972 | 37.8572 | 202.496 | 15.8192 | 50 | 47.31 | 524288 | 1.44179e+06 | 79.4 | tex_throttle | 58.9 | barrier | 13.61 | short_scoreboard | 9.61 |
| legacy | 1048576 | 1 | b1 | all | 1577:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 64 | NA | NA | NA | 69.12 | 9.5571 | 1.90212e+07 | 8832 | 4.11784e+07 | 275.319 | 113.418 | 595.753 | 46.5407 | 33.33 | 31.79 | 11191 | 4144 | 0 | long_scoreboard | 60.59 | long_scoreboard_pipe_l1tex | 60.59 | barrier | 12.73 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy | 1048576 | 1 | b1 | all | 5 | 723.232 | 9.39944e+07 | 2.80125 | 1.15155 | 2.43259 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
