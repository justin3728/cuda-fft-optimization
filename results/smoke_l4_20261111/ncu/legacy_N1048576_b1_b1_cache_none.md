# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy | 1048576 | 1 | b1 | none | 1894:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 44 | NA | NA | NA | 41.12 | 6.53047 | 1.01972e+07 | 813440 | 3.99072e+07 | 267.77 | 110.308 | 970.505 | 75.8167 | 83.33 | 42.41 | 11228 | 16038 | 0 | mio_throttle | 29.3 | mio_throttle_pipe_mio | 29.3 | lg_throttle | 18.98 |
| legacy | 1048576 | 1 | b1 | none | 1894:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | NA | NA | NA | 192.224 | 30.528 | 128 | 330752 | 4.09221e+07 | 1.72133 | 0.709103 | 212.888 | 16.631 | 50 | 47.25 | 524288 | 1.44179e+06 | 83.24 | tex_throttle | 62.78 | barrier | 13.62 | short_scoreboard | 10.02 |
| legacy | 1048576 | 1 | b1 | none | 1894:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 42 | NA | NA | NA | 176.896 | 28.0937 | 9.77651e+06 | 1.11027e+06 | 5.05006e+07 | 61.5434 | 25.3529 | 285.482 | 22.3021 | 83.33 | 73.54 | 1244 | 3284 | 82.95 | tex_throttle | 52.67 | short_scoreboard | 34.55 | barrier | 8.31 |
| legacy | 1048576 | 1 | b1 | none | 1894:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | NA | NA | NA | 192.736 | 30.6093 | 512 | 89856 | 4.08351e+07 | 0.468869 | 0.193151 | 211.871 | 16.5515 | 50 | 47.17 | 524288 | 1.44179e+06 | 83.11 | tex_throttle | 62.79 | barrier | 13.5 | short_scoreboard | 9.97 |
| legacy | 1048576 | 1 | b1 | none | 1894:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 64 | NA | NA | NA | 26.688 | 4.23845 | 384 | 77696 | 4.0528e+07 | 2.92566 | 1.20523 | 1518.59 | 118.633 | 33.33 | 30.56 | 10501 | 29634 | 0 | long_scoreboard | 26.95 | long_scoreboard_pipe_l1tex | 26.95 | lg_throttle | 25.62 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy | 1048576 | 1 | b1 | none | 5 | 629.664 | 2.23968e+07 | 0.667477 | 1.15155 | 0.579634 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
