# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 13041:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 331.392 | 52.3692 | 512 | 416896 | 5.59941e+07 | 1.25956 | 0.518705 | 168.966 | 13.2071 | 16.67 | 16.56 | 131072 | 262144 | 73.38 | short_scoreboard | 40.65 | tex_throttle | 24.95 | wait | 13.79 | 0.512514 | 11.3643 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 13041:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 301.408 | 47.6308 | 1.01416e+07 | 741248 | 3.5457e+07 | 36.1066 | 14.8692 | 117.638 | 9.19503 | 16.67 | 16.35 | 131072 | 1.04858e+06 | 67.14 | short_scoreboard | 44.52 | tex_throttle | 24.17 | wait | 11.92 | 13.9515 | 7.91207 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 2 | 632.8 | 1.13002e+07 | 0.336773 | 1.1516 | 0.292439 | True | False | 2 | 2 | 1 | 1 | False | 632.8 | 1.13002e+07 | 0.336773 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
