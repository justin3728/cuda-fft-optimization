# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 31076:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 34 | 0 | 65536 | 65536 | 87.552 | 54.7967 | 1.68329e+07 | 2.43507e+06 | 6.35942e+07 | 220.075 | 16.1443 | 726.359 | 25.4713 | 25 | 21.69 | 142629 | 269371 | 16.68 | long_scoreboard | 31.45 | wait | 29.45 | short_scoreboard | 14.74 | 15.0581 | 26.5023 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 31076:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 72.224 | 45.2033 | 1.67981e+07 | 2.39974e+06 | 5.71394e+07 | 265.809 | 19.4994 | 791.142 | 27.743 | 25 | 22.43 | 163521 | 1.06154e+06 | 18.41 | long_scoreboard | 29.69 | wait | 29.34 | short_scoreboard | 13.2 | 18.1882 | 28.866 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 2 | 159.776 | 3.84658e+07 | 1.14637 | 0.996675 | 1.15019 | True | False | 2 | 2 | 1 | 1 | False | 159.776 | 3.84658e+07 | 1.14637 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
