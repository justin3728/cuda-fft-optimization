# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=4194304 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} | 262144 | 1 | b1 | all | 15914:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 38 | 0 | 8192 | 8192 | 74.176 | 54.0075 | 5.98298e+06 | 128 | 1.64053e+07 | 80.6609 | 33.2221 | 221.168 | 17.2882 | 100 | 81.96 | 131072 | 360448 | 69.78 | barrier | 34.93 | tex_throttle | 26.26 | long_scoreboard | 18.64 | 31.045 | 15.1984 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=1,r=1] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=4194304 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} | 262144 | 1 | b1 | all | 15914:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (512, 1, 1) | (256, 1, 1) | 38 | 0 | 8192 | 8192 | 63.168 | 45.9925 | 4.66534e+06 | 256 | 1.30433e+07 | 73.8602 | 30.4211 | 206.486 | 16.1406 | 100 | 82.43 | 131072 | 360448 | 66.63 | barrier | 38.21 | tex_throttle | 22.99 | long_scoreboard | 20.16 | 28.4276 | 14.1895 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=4194304 pass1{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} pass2{grid=(512,1,1),block=(256,1,1),smem_bytes=8192} | 262144 | 1 | b1 | all | 2 | 137.344 | 1.06487e+07 | 1.26942 | 1.15165 | 1.10227 | True | False | 2 | 2 | 1 | 1 | False | 137.344 | 1.06487e+07 | 1.26942 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
