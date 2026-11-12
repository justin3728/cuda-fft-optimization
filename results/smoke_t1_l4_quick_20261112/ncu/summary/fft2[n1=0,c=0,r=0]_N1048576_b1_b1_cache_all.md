# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 12872:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 380.416 | 53.4893 | 1.97631e+07 | 59392 | 5.59238e+07 | 52.1073 | 21.4586 | 147.007 | 11.4906 | 16.67 | 16.57 | 131072 | 262144 | 63.32 | short_scoreboard | 35.09 | tex_throttle | 21.47 | long_scoreboard | 20.84 | 20.0594 | 9.88738 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 12872:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 330.784 | 46.5107 | 1.86445e+07 | 42880 | 3.53866e+07 | 56.4941 | 23.2651 | 106.978 | 8.36181 | 16.67 | 16.63 | 131072 | 1.04858e+06 | 60.63 | short_scoreboard | 39.39 | tex_throttle | 21.48 | long_scoreboard | 18.39 | 21.7472 | 7.19512 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | all | 2 | 711.2 | 3.85098e+07 | 1.14768 | 1.1516 | 0.996599 | True | False | 2 | 2 | 1 | 1 | False | 711.2 | 3.85098e+07 | 1.14768 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
