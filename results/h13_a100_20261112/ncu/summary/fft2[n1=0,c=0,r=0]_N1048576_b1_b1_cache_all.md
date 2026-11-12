# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | all | 26029:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 34 | 0 | 131072 | 131072 | 152.512 | 56.5295 | 1.68326e+07 | 2.32115e+06 | 5.85327e+07 | 125.589 | 9.21299 | 383.791 | 13.4584 | 12.5 | 12.43 | 1548 | 2981 | 11.42 | wait | 33.72 | long_scoreboard | 30.9 | short_scoreboard | 14.47 | 8.59449 | 14.0032 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | all | 26029:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 38 | 0 | 131072 | 131072 | 117.28 | 43.4705 | 1.67976e+07 | 2.34867e+06 | 5.59372e+07 | 163.252 | 11.9759 | 476.955 | 16.7254 | 12.5 | 12.39 | 8772 | 926012 | 12.47 | wait | 34.08 | long_scoreboard | 28.8 | short_scoreboard | 12.43 | 11.1714 | 17.4024 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | all | 2 | 269.792 | 3.83e+07 | 1.14143 | 0.996675 | 1.14524 | True | False | 2 | 2 | 1 | 1 | False | 269.792 | 3.83e+07 | 1.14143 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
