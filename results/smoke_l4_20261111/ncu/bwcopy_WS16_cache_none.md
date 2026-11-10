# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bwcopy | 0 | 0 | WS16 | none | 3119:1:13:0 | copy16 | (232, 1, 1) | (256, 1, 1) | 16 | NA | NA | NA | 9.12 | 100 | 128 | 38400 | 1.68361e+07 | 4.22456 | 1.74031 | 1846.06 | 144.216 | 100 | 63 | 0 | 0 | 0 | long_scoreboard | 85.41 | long_scoreboard_pipe_l1tex | 85.41 | branch_resolving | 3.05 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bwcopy | 0 | 0 | WS16 | none | 1 | 9.12 | 38528 | NA | NA | NA |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
