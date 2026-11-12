# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 15580:1:13:0 | unnamed>::pass1_columns<unnamed>::KernelVariant<0, 0, 1>> | (64, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 138.272 | 53.6504 | 4.67661e+06 | 0 | 1.01297e+07 | 33.8218 | 13.9303 | 73.2592 | 5.72653 | 16.67 | 16.55 | 0 | 0 | 61.95 | short_scoreboard | 35.74 | long_scoreboard | 21.61 | long_scoreboard_pipe_l1tex | 21.61 | 13.0174 | 5.0343 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| fft2[n1=0,c=0,r=0] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 15580:1:13:1 | unnamed>::pass2_rows<unnamed>::KernelVariant<0, 0, 1>> | (64, 1, 1) | (256, 1, 1) | 38 | 0 | 65536 | 65536 | 119.456 | 46.3496 | 4.67891e+06 | 0 | 8.77568e+06 | 39.1685 | 16.1325 | 73.4637 | 5.74251 | 16.67 | 16.69 | 0 | 229376 | 58.34 | short_scoreboard | 38.82 | long_scoreboard | 20.9 | long_scoreboard_pipe_l1tex | 20.9 | 15.0753 | 5.04836 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fft2[n1=0,c=0,r=0] | fft2 N=262144 batch=1 N1=512 N2=512 index_mode=0 smem_padding=0 C=8 R=8 workspace_bytes=4194304 pass1{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} pass2{grid=(64,1,1),block=(256,1,1),smem_bytes=65536} | 262144 | 1 | b1 | all | 2 | 257.728 | 9.35552e+06 | 1.11526 | 1.15165 | 0.968408 | True | False | 2 | 2 | 1 | 1 | False | 257.728 | 9.35552e+06 | 1.11526 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
