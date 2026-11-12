# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 1 | b1 | all | 3340:1:13:0 | VkFFT_main | (64, 1, 1) | (8, 16, 1) | 84 | 0 | 16384 | 16384 | 7.136 | 37.0432 | 1.06893e+06 | 0 | 3.81837e+06 | 149.794 | 10.992 | 535.085 | 18.7216 | 31.25 | 6.47 | 0 | 0 | 23.83 | long_scoreboard | 24.25 | wait | 22.1 | imc_miss | 20.75 | 10.2923 | 19.5211 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |
| vkfft |  | 65536 | 1 | b1 | all | 3340:1:13:1 | VkFFT_main | (16, 1, 1) | (8, 64, 1) | 62 | 0 | 73728 | 73728 | 12.128 | 62.9568 | 1.06419e+06 | 0 | 3.64141e+06 | 87.7467 | 6.43892 | 300.248 | 10.5051 | 50 | 24.22 | 0 | 0 | 31.1 | math_pipe_throttle | 17.6 | mio_throttle | 15.93 | long_scoreboard | 14.36 | 6.02906 | 10.9537 | total_lts_bytes/read_plateau | True | False | 2 | 2 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 2 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vkfft |  | 65536 | 1 | b1 | all | 2 | 19.264 | 2.13312e+06 | 1.01715 | 0.99669 | 1.02053 | True | False | 2 | 2 | 1 | 1 | False | 19.264 | 2.13312e+06 | 1.01715 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.

Exported kernel count: 2; captured launch count: 2; expected execution launches: 2.
