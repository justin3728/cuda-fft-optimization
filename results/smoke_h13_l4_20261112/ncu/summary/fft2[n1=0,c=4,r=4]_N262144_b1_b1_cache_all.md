# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=4194304 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} | 262144 | 1 | b1 | all | 16586:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 38 | 0 | 32768 | 32768 | 98.592 | 53.958 | 4.66061e+06 | 0 | 1.14314e+07 | 47.2717 | 19.47 | 115.946 | 9.0633 | 50 | 32.62 | 33420 | 66096 | 64.3 | tex_throttle | 35.74 | long_scoreboard | 24.91 | long_scoreboard_pipe_l1tex | 24.91 | 18.194 | 7.96773 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=4,r=4] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=4194304 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} | 262144 | 1 | b1 | all | 16586:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (128, 1, 1) | (256, 1, 1) | 38 | 0 | 32768 | 32768 | 84.128 | 46.042 | 4.67891e+06 | 0 | 8.97293e+06 | 55.6166 | 22.907 | 106.658 | 8.33725 | 50 | 32.33 | 33813 | 263107 | 60.95 | tex_throttle | 35.97 | long_scoreboard | 26.34 | long_scoreboard_pipe_l1tex | 26.34 | 21.4059 | 7.32944 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=4,r=4] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=4 R=4 workspace_bytes=4194304 pass1{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} pass2{grid=(128,1,1),block=(256,1,1),smem_bytes=32768} | 262144 | 1 | b1 | all | 2 | 182.72 | 9.33952e+06 | 1.11336 | 1.15165 | 0.966752 | True | False | 2 | 2 | 1 | 1 | False | 182.72 | 9.33952e+06 | 1.11336 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
