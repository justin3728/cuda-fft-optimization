# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | none | 27928:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (1024, 1, 1) | (256, 1, 1) | 34 | 0 | 16384 | 16384 | 102.272 | 58.1408 | 1.90598e+07 | 1.98903e+07 | 1.3742e+08 | 380.849 | 27.9384 | 1343.67 | 47.1186 | 75 | 61.18 | 548006 | 1.47343e+06 | 11.17 | long_scoreboard | 39.35 | mio_throttle | 15.94 | short_scoreboard | 12.56 | 25.7532 | 49.0258 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | none | 27928:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (1024, 1, 1) | (256, 1, 1) | 38 | 0 | 16384 | 16384 | 73.632 | 41.8592 | 1.74568e+07 | 1.01775e+07 | 9.65564e+07 | 375.303 | 27.5316 | 1311.34 | 45.9848 | 75 | 61.39 | 575453 | 1.45223e+06 | 12.97 | long_scoreboard | 29.48 | mio_throttle | 22.01 | barrier | 13.45 | 25.4897 | 47.846 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=1,r=1] | fft2 N=1048576 batch=1 N1=1024 N2=1024 index_mode=0 smem_padding=0 C=1 R=1 workspace_bytes=16777216 pass1{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(1024,1,1),block=(256,1,1),smem_bytes=16384} | 1048576 | 1 | b1 | none | 2 | 175.904 | 6.65844e+07 | 1.98437 | 0.996675 | 1.99099 | True | False | 2 | 2 | 1 | 1 | False | 175.904 | 6.65844e+07 | 1.98437 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
