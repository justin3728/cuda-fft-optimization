# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | none | 29622:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 34 | 0 | 32768 | 32768 | 78.08 | 55.9633 | 1.67743e+07 | 1.76111e+07 | 8.77006e+07 | 440.387 | 32.3061 | 1123.21 | 39.3879 | 50 | 42.37 | 410463 | 798858 | 16.17 | long_scoreboard | 42.4 | wait | 15.26 | short_scoreboard | 14.45 | 29.7778 | 40.9821 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | none | 29622:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 38 | 0 | 32768 | 32768 | 61.44 | 44.0367 | 1.67988e+07 | 1.11219e+07 | 6.9982e+07 | 454.44 | 33.337 | 1139.03 | 39.9425 | 50 | 42.51 | 429293 | 1.32328e+06 | 17.34 | long_scoreboard | 36.62 | wait | 15.12 | mio_throttle | 12.63 | 30.836 | 41.5592 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | none | 2 | 139.52 | 6.23062e+07 | 1.85687 | 0.996675 | 1.86306 | True | False | 2 | 2 | 1 | 1 | False | 139.52 | 6.23062e+07 | 1.85687 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
