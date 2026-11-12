# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=8,r=8] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 32506:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 34 | 0 | 131072 | 131072 | 154.208 | 56.2507 | 1.54159e+07 | 1.57647e+07 | 6.91132e+07 | 202.199 | 14.833 | 448.182 | 15.7164 | 12.5 | 12.32 | 1279 | 2747 | 11.26 | wait | 33.44 | long_scoreboard | 31.34 | short_scoreboard | 14.34 | 13.6749 | 16.3526 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=8,r=8] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 32506:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 38 | 0 | 131072 | 131072 | 119.936 | 43.7493 | 1.67973e+07 | 9.49939e+06 | 6.68581e+07 | 219.256 | 16.0843 | 557.448 | 19.5481 | 12.5 | 12.56 | 9004 | 923654 | 11.99 | long_scoreboard | 32.54 | wait | 32.51 | short_scoreboard | 11.86 | 14.8946 | 20.3393 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=8,r=8] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=16777216 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=131072} | 1048576 | 1 | b1 | none | 2 | 274.144 | 5.74774e+07 | 1.71296 | 0.996675 | 1.71867 | True | False | 2 | 2 | 1 | 1 | False | 274.144 | 5.74774e+07 | 1.71296 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
