# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 11851:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 44 | 16896 | 0 | 16896 | 40.768 | 6.48478 | 9.96403e+06 | 783872 | 3.97888e+07 | 263.636 | 108.569 | 975.981 | 76.2864 | 83.33 | 43.84 | 11447 | 14413 | 0 | mio_throttle | 29.62 | mio_throttle_pipe_mio | 29.62 | lg_throttle | 19.08 | 101.896 | 65.6424 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 11851:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 192.608 | 30.6373 | 640 | 310016 | 4.08597e+07 | 1.61289 | 0.664212 | 212.139 | 16.5816 | 50 | 47.13 | 524288 | 1.44179e+06 | 83.09 | tex_throttle | 63.24 | barrier | 13.51 | short_scoreboard | 10.02 | 0.656255 | 14.268 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 11851:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 42 | 16896 | 0 | 16896 | 175.712 | 27.9497 | 9.69024e+06 | 1.16314e+06 | 5.05029e+07 | 61.768 | 25.4369 | 287.419 | 22.4658 | 83.33 | 73.84 | 1177 | 3236 | 83.3 | tex_throttle | 53.1 | short_scoreboard | 34.69 | barrier | 7.54 | 23.9201 | 19.3312 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 11851:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 193.152 | 30.7238 | 384 | 87040 | 4.08714e+07 | 0.452618 | 0.186394 | 211.602 | 16.5396 | 50 | 47.2 | 524288 | 1.44179e+06 | 83.19 | tex_throttle | 63.06 | barrier | 13.49 | short_scoreboard | 9.99 | 0.184138 | 14.2319 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | none | 11851:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 64 | 33792 | 0 | 33792 | 26.432 | 4.20442 | 384 | 92672 | 4.04731e+07 | 3.52058 | 1.44983 | 1531.22 | 119.686 | 33.33 | 30.56 | 10744 | 28505 | 0 | long_scoreboard | 26.96 | long_scoreboard_pipe_l1tex | 26.96 | lg_throttle | 26.09 | 1.4323 | 102.986 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | none | 5 | 628.672 | 2.20924e+07 | 0.658405 | 1.1516 | 0.571731 | True | False | 5 | 5 | 1 | 1 | False | 628.672 | 2.20924e+07 | 0.658405 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
