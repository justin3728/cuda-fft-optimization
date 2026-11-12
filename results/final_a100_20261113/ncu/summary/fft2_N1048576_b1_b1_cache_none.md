# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | none | 7599:1:13:0 | unnamed>::pass1_columns<unnamed>::TilePass<10, 3, 2>> | (512, 1, 1) | (256, 1, 1) | 66 | 0 | 32768 | 32768 | 57.76 | 54.7467 | 1.67222e+07 | 1.717e+07 | 8.68072e+07 | 586.777 | 42.9821 | 1502.89 | 51.567 | 37.5 | 33.03 | 364 | 394621 | 20.96 | long_scoreboard | 38.89 | lg_throttle | 16.31 | mio_throttle | 11.26 | 39.7332 | 53.2476 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | none | 7599:1:13:1 | unnamed>::pass2_rows<unnamed>::TilePass<10, 3, 2>> | (512, 1, 1) | (256, 1, 1) | 60 | 0 | 32768 | 32768 | 47.744 | 45.2533 | 1.6806e+07 | 1.09102e+07 | 6.94535e+07 | 580.517 | 42.5236 | 1454.71 | 49.9136 | 50 | 43.21 | 17675 | 920927 | 24.16 | long_scoreboard | 33.66 | mio_throttle | 20.09 | lg_throttle | 13.6 | 39.4399 | 51.5403 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | none | 2 | 105.504 | 6.16084e+07 | 1.83607 | 0.996665 | 1.84222 | True | False | 2 | 2 | 1 | 1 | False | 105.504 | 6.16084e+07 | 1.83607 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
