# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | all | 27718:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (1024, 1, 1) | (256, 1, 1) | 34 | 0 | 16384 | 16384 | 99.616 | 55.5496 | 1.96623e+07 | 5.37728e+06 | 1.27316e+08 | 251.361 | 18.4395 | 1278.07 | 44.8183 | 75 | 63.31 | 544921 | 1.47316e+06 | 11.48 | long_scoreboard | 38.64 | mio_throttle | 15.75 | short_scoreboard | 12.24 | 17.1525 | 46.6323 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | all | 27718:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (1024, 1, 1) | (256, 1, 1) | 38 | 0 | 16384 | 16384 | 79.712 | 44.4504 | 1.92287e+07 | 4.93632e+06 | 9.01972e+07 | 303.154 | 22.2389 | 1131.54 | 39.6798 | 75 | 59.62 | 566973 | 1.45078e+06 | 12.14 | long_scoreboard | 27.2 | mio_throttle | 23.23 | barrier | 14.52 | 20.6933 | 41.2858 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | all | 2 | 179.328 | 4.92046e+07 | 1.46641 | 0.996675 | 1.4713 | True | False | 2 | 2 | 1 | 1 | False | 179.328 | 4.92046e+07 | 1.46641 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
