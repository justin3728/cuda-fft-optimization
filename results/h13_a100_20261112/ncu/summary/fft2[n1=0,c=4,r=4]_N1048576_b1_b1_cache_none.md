# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 31279:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 34 | 0 | 65536 | 65536 | 93.184 | 55.0265 | 1.66284e+07 | 1.75994e+07 | 7.6835e+07 | 367.313 | 26.9455 | 824.551 | 28.9146 | 25 | 21.7 | 144164 | 267761 | 15.39 | long_scoreboard | 36.79 | wait | 27.22 | short_scoreboard | 13.71 | 24.8352 | 30.0849 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 31279:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 76.16 | 44.9735 | 1.67976e+07 | 1.08918e+07 | 6.80276e+07 | 363.568 | 26.6708 | 893.219 | 31.3226 | 25 | 23.15 | 162291 | 1.05887e+06 | 17.53 | long_scoreboard | 34.91 | wait | 26.93 | short_scoreboard | 12.43 | 24.6737 | 32.5904 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=16777216 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=65536} | 1048576 | 1 | b1 | none | 2 | 169.344 | 6.19171e+07 | 1.84527 | 0.996675 | 1.85143 | True | False | 2 | 2 | 1 | 1 | False | 169.344 | 6.19171e+07 | 1.84527 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
