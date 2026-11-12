# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft | 1048576 | 1 | b1 | all | 2212:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | NA | NA | NA | 413.92 | 54.9794 | 1.99338e+07 | 256 | 3.43234e+07 | 48.1593 | 19.8393 | 82.9228 | 6.478 | 66.67 | 65.61 | 0 | 131072 | 74.41 | tex_throttle | 74.24 | lg_throttle | 9.74 | long_scoreboard | 5.53 |
| cufft | 1048576 | 1 | b1 | all | 2212:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | NA | NA | NA | 338.944 | 45.0206 | 2.11224e+07 | 0 | 3.43276e+07 | 62.3184 | 25.6721 | 101.278 | 7.91192 | 66.67 | 65.7 | 0 | 131072 | 68.95 | tex_throttle | 70.1 | lg_throttle | 14.21 | long_scoreboard | 5.53 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft | 1048576 | 1 | b1 | all | 2 | 752.864 | 4.10565e+07 | 1.22358 | 1.15155 | 1.06255 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
