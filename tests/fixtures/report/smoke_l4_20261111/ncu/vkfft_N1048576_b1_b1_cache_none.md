# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft | 1048576 | 1 | b1 | none | 2712:1:13:0 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 254 | NA | NA | NA | 324.544 | 54.6532 | 1.9766e+07 | 1.72342e+07 | 5.12031e+07 | 114.007 | 46.9652 | 157.769 | 12.3251 | 8.33 | 7.48 | 0 | 131072 | 69.29 | tex_throttle | 53.3 | short_scoreboard | 27.34 | lg_throttle | 6.94 |
| vkfft | 1048576 | 1 | b1 | none | 2712:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | NA | NA | NA | 269.28 | 45.3468 | 1.10181e+07 | 871296 | 3.4518e+07 | 44.1526 | 18.1887 | 128.186 | 10.014 | 8.33 | 8.1 | 298095 | 275608 | 76.03 | short_scoreboard | 47.96 | tex_throttle | 37.33 | long_scoreboard | 4.33 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft | 1048576 | 1 | b1 | none | 2 | 593.824 | 4.88896e+07 | 1.45702 | 1.15155 | 1.26527 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2.
