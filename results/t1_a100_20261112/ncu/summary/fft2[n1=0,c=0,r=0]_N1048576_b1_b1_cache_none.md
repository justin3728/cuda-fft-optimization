# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 9622:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 34 | 0 | 131072 | 131072 | 154.176 | 56.0885 | 1.53266e+07 | 1.58216e+07 | 6.9138e+07 | 202.03 | 14.8251 | 448.436 | 15.6899 | 12.5 | 12.29 | 1469 | 2738 | 11.25 | wait | 33.45 | long_scoreboard | 31.16 | short_scoreboard | 14.35 | 13.6697 | 16.3599 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 9622:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 38 | 0 | 131072 | 131072 | 120.704 | 43.9115 | 1.67982e+07 | 9.38688e+06 | 6.67699e+07 | 216.936 | 15.919 | 553.17 | 19.3544 | 12.5 | 12.53 | 8338 | 923701 | 11.95 | long_scoreboard | 32.83 | wait | 32.6 | short_scoreboard | 11.89 | 14.7452 | 20.1808 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 2 | 274.88 | 5.73332e+07 | 1.70866 | 0.99669 | 1.71434 | True | False | 2 | 2 | 1 | 1 | False | 274.88 | 5.73332e+07 | 1.70866 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
