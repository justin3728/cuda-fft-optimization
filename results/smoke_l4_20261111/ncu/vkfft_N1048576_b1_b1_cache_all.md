# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft | 1048576 | 1 | b1 | all | 2544:1:13:0 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 254 | NA | NA | NA | 341.632 | 54.2177 | 4.01475e+07 | 2.20314e+06 | 5.12031e+07 | 123.966 | 51.0678 | 149.878 | 11.7086 | 8.33 | 8.2 | 0 | 131072 | 64.97 | tex_throttle | 45.98 | short_scoreboard | 23.33 | lg_throttle | 14.21 |
| vkfft | 1048576 | 1 | b1 | all | 2544:1:13:1 | VkFFT_main | (256, 1, 1) | (4, 32, 1) | 168 | NA | NA | NA | 288.48 | 45.7823 | 1.87099e+07 | 14976 | 3.44677e+07 | 64.9087 | 26.7392 | 119.481 | 9.33392 | 8.33 | 8.32 | 292224 | 265139 | 70.04 | short_scoreboard | 42.44 | tex_throttle | 33.03 | long_scoreboard | 13.74 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft | 1048576 | 1 | b1 | all | 2 | 630.112 | 6.10755e+07 | 1.82019 | 1.15155 | 1.58065 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2.
