# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bwcopy | 0 | 0 | WS4096 | all | 2883:1:13:0 | copy16 | (232, 1, 1) | (256, 1, 1) | 16 | NA | NA | NA | 18359.2 | 100 | 2.47752e+09 | 2.46835e+09 | 4.29533e+09 | 269.395 | 110.978 | 233.961 | 18.2772 | 100 | 66.13 | 0 | 0 | 0 | long_scoreboard | 98.78 | long_scoreboard_pipe_l1tex | 98.78 | lg_throttle | 0.48 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bwcopy | 0 | 0 | WS4096 | all | 1 | 18359.2 | 4.94586e+09 | NA | NA | NA |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
