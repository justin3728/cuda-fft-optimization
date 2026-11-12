# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | all | 7387:1:13:0 | unnamed>::pass1_columns<unnamed>::TilePass<10, 3, 2>> | (512, 1, 1) | (256, 1, 1) | 66 | 0 | 32768 | 32768 | 52.64 | 54.0763 | 1.68599e+07 | 3.36832e+06 | 7.36715e+07 | 384.275 | 28.1486 | 1399.53 | 48.0206 | 37.5 | 32.58 | 427 | 394824 | 23.08 | long_scoreboard | 36.5 | lg_throttle | 14.48 | mio_throttle | 10.67 | 26.2812 | 49.5856 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | all | 7387:1:13:1 | unnamed>::pass2_rows<unnamed>::TilePass<10, 3, 2>> | (512, 1, 1) | (256, 1, 1) | 60 | 0 | 32768 | 32768 | 44.704 | 45.9237 | 1.68051e+07 | 2.44237e+06 | 6.06178e+07 | 430.554 | 31.5386 | 1355.98 | 46.5261 | 50 | 43.03 | 19852 | 921478 | 26 | long_scoreboard | 27.34 | mio_throttle | 21.41 | lg_throttle | 14.66 | 29.4803 | 48.0424 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2 | fft2 N=1048576 batch=1 N1=1024 N2=1024 radix=(8,8) C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),lanes=2,smem_bytes=32768} | 1048576 | 1 | b1 | all | 2 | 97.344 | 3.94757e+07 | 1.17647 | 0.996665 | 1.1804 | True | False | 2 | 2 | 1 | 1 | False | 97.344 | 3.94757e+07 | 1.17647 |

Copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
