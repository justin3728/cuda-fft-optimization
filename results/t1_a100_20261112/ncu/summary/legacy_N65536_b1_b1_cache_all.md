# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 65536 | 1 | b1 | all | 2728:1:13:0 | transpose_opt | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 4.256 | 11.1577 | 1.05242e+06 | 0 | 3.64992e+06 | 247.278 | 18.1455 | 857.594 | 30.0056 | 100 | 12.15 | 0 | 0 | 0 | long_scoreboard | 48.68 | imc_miss | 25 | drain | 6.2 | 16.9904 | 31.2869 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 2728:1:13:1 | fft_block_mixed_radix<256> | (256, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 12.16 | 31.8792 | 1.08531e+06 | 0 | 4.19203e+06 | 89.2526 | 6.54943 | 344.739 | 12.0618 | 25 | 21.89 | 40960 | 90112 | 4.57 | barrier | 44.31 | long_scoreboard | 18.85 | imc_miss | 12.69 | 6.13253 | 12.5768 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 2728:1:13:2 | transpose_and_twiddle | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 5.632 | 14.7651 | 1.06304e+06 | 0 | 3.72301e+06 | 188.75 | 13.8506 | 661.045 | 23.1287 | 100 | 12.49 | 0 | 0 | 16.78 | long_scoreboard | 28.12 | imc_miss | 23.72 | wait | 20.48 | 12.969 | 24.1164 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 2728:1:13:3 | fft_block_mixed_radix<256> | (256, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 11.904 | 31.2081 | 1.08544e+06 | 0 | 4.33184e+06 | 91.1828 | 6.69106 | 363.898 | 12.7321 | 25 | 21.89 | 40960 | 90112 | 4.69 | barrier | 41.06 | long_scoreboard | 17.84 | imc_miss | 11.15 | 6.26515 | 13.2758 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 2728:1:13:4 | transpose_opt | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 4.192 | 10.9899 | 1.05242e+06 | 0 | 3.74102e+06 | 251.053 | 18.4225 | 892.42 | 31.2241 | 100 | 12.26 | 0 | 0 | 0 | long_scoreboard | 48.73 | imc_miss | 24.66 | drain | 6.29 | 17.2498 | 32.5574 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 65536 | 1 | b1 | all | 5 | 38.144 | 5.33862e+06 | 2.54565 | 0.99669 | 2.55411 | True | False | 5 | 5 | 1 | 1 | False | 38.144 | 5.33862e+06 | 2.54565 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
