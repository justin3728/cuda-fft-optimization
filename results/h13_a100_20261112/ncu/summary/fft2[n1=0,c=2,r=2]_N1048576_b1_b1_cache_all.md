# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | all | 29414:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 34 | 0 | 32768 | 32768 | 71.68 | 55.5556 | 1.68332e+07 | 2.50803e+06 | 7.30766e+07 | 269.827 | 19.7941 | 1019.48 | 35.7503 | 50 | 40.99 | 409682 | 802778 | 17.91 | long_scoreboard | 34.05 | wait | 17.47 | short_scoreboard | 16.48 | 18.4604 | 37.1974 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | all | 29414:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 38 | 0 | 32768 | 32768 | 57.344 | 44.4444 | 1.67977e+07 | 2.4759e+06 | 5.99863e+07 | 336.105 | 24.6561 | 1046.08 | 36.6829 | 50 | 40.45 | 431071 | 1.32976e+06 | 18.48 | long_scoreboard | 28.62 | wait | 16.85 | mio_throttle | 14.35 | 22.9958 | 38.1677 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=16777216 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=32768} | 1048576 | 1 | b1 | all | 2 | 129.024 | 3.86148e+07 | 1.15081 | 0.996675 | 1.15465 | True | False | 2 | 2 | 1 | 1 | False | 129.024 | 3.86148e+07 | 1.15081 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
