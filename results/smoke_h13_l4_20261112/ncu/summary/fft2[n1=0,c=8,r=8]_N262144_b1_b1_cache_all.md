# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=8,r=8] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 16924:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (64, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 137.344 | 53.4829 | 4.67661e+06 | 0 | 1.01278e+07 | 34.0503 | 14.0244 | 73.7404 | 5.76414 | 16.67 | 16.66 | 0 | 0 | 62.18 | short_scoreboard | 35.98 | long_scoreboard | 21.89 | long_scoreboard_pipe_l1tex | 21.89 | 13.1054 | 5.06737 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=8,r=8] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 16924:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (64, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 119.456 | 46.5171 | 4.68339e+06 | 0 | 8.7753e+06 | 39.206 | 16.1479 | 73.4605 | 5.74226 | 16.67 | 16.63 | 0 | 229376 | 58.23 | short_scoreboard | 38.8 | long_scoreboard | 20.93 | long_scoreboard_pipe_l1tex | 20.93 | 15.0897 | 5.04813 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=8,r=8] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 2 | 256.8 | 9.36e+06 | 1.1158 | 1.15165 | 0.968872 | True | False | 2 | 2 | 1 | 1 | False | 256.8 | 9.36e+06 | 1.1158 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
