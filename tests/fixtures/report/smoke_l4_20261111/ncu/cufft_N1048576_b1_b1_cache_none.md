# Per-kernel profile

| impl | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft | 1048576 | 1 | b1 | none | 2376:1:13:0 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | NA | NA | NA | 383.264 | 55.0591 | 5888 | 116608 | 3.4325e+07 | 0.319613 | 0.131665 | 89.5597 | 6.99648 | 66.67 | 65.74 | 0 | 131072 | 83.16 | tex_throttle | 87.33 | short_scoreboard | 3.04 | barrier | 2.53 |
| cufft | 1048576 | 1 | b1 | none | 2376:1:13:1 | regular_fft_factor<1024, EPT<8>, 8, 0, 6, 0, 2, 1, unsigned int, double, HostConfigPlaceholder> | (128, 1, 1) | (8, 128, 1) | 60 | NA | NA | NA | 312.832 | 44.9409 | 1.00584e+07 | 1.42976e+06 | 3.43288e+07 | 36.723 | 15.1281 | 109.736 | 8.57264 | 66.67 | 63.7 | 0 | 131072 | 77.02 | tex_throttle | 84.47 | lg_throttle | 3.78 | barrier | 3.37 |

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cufft | 1048576 | 1 | b1 | none | 2 | 696.096 | 1.16106e+07 | 0.346024 | 1.15155 | 0.300485 |

Percentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.
