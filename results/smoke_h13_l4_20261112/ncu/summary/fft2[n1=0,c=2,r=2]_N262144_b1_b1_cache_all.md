# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=4194304 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} | 262144 | 1 | b1 | all | 16252:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 16384 | 16384 | 88.032 | 54.681 | 5.54496e+06 | 0 | 1.33065e+07 | 62.988 | 25.9431 | 151.156 | 11.8155 | 83.33 | 56.71 | 98853 | 197464 | 64.13 | tex_throttle | 41.89 | long_scoreboard | 25.45 | long_scoreboard_pipe_l1tex | 25.45 | 24.243 | 10.3873 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=2,r=2] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=4194304 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} | 262144 | 1 | b1 | all | 16252:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (256, 1, 1) | (256, 1, 1) | 38 | 0 | 16384 | 16384 | 72.96 | 45.319 | 4.6601e+06 | 0 | 9.18131e+06 | 63.8719 | 26.3072 | 125.84 | 9.83669 | 83.33 | 56.87 | 98911 | 328545 | 61.63 | tex_throttle | 43.42 | long_scoreboard | 29.56 | long_scoreboard_pipe_l1tex | 29.56 | 24.5832 | 8.64763 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=2,r=2] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=2 R=2 workspace_bytes=4194304 pass1{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} pass2{grid=(256,1,1),block=(256,1,1),smem_bytes=16384} | 262144 | 1 | b1 | all | 2 | 160.992 | 1.02051e+07 | 1.21654 | 1.15165 | 1.05635 | True | False | 2 | 2 | 1 | 1 | False | 160.992 | 1.02051e+07 | 1.21654 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
