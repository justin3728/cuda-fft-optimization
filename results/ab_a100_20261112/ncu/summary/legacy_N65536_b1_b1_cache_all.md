# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 65536 | 1 | b1 | all | 18413:1:13:0 | transpose_opt | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 4.224 | 10.9635 | 1.05229e+06 | 128 | 3.64227e+06 | 249.152 | 18.2922 | 862.28 | 32.0787 | 100 | 12.5 | 0 | 0 | 0 | long_scoreboard | 50.74 | imc_miss | 24.67 | drain | 6.06 | 17.1224 | 30.7269 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 18413:1:13:1 | fft_block_mixed_radix<256> | (256, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 12.416 | 32.2259 | 1.08531e+06 | 128 | 4.19795e+06 | 87.4227 | 6.4184 | 338.108 | 12.5784 | 25 | 23.12 | 40960 | 90112 | 4.73 | barrier | 42.53 | long_scoreboard | 18.5 | imc_miss | 13.26 | 6.00795 | 12.0483 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 18413:1:13:2 | transpose_and_twiddle | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 5.6 | 14.5349 | 1.06304e+06 | 128 | 3.63581e+06 | 189.851 | 13.9385 | 649.251 | 24.1536 | 100 | 12.35 | 0 | 0 | 17.08 | long_scoreboard | 27.01 | imc_miss | 22.12 | wait | 20.55 | 13.0472 | 23.1357 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 18413:1:13:3 | fft_block_mixed_radix<256> | (256, 1, 1) | (256, 1, 1) | 96 | 16896 | 0 | 16896 | 12.064 | 31.3123 | 1.08544e+06 | 0 | 4.34835e+06 | 89.9735 | 6.60567 | 360.44 | 13.4092 | 25 | 22.09 | 40960 | 90112 | 4.68 | barrier | 40.93 | long_scoreboard | 19.22 | imc_miss | 11.39 | 6.18327 | 12.8441 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 65536 | 1 | b1 | all | 18413:1:13:4 | transpose_opt | (8, 8, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 4.224 | 10.9635 | 1.05229e+06 | 0 | 3.66694e+06 | 249.121 | 18.29 | 868.121 | 32.296 | 100 | 12.4 | 0 | 0 | 0 | long_scoreboard | 51.19 | imc_miss | 24.44 | drain | 5.96 | 17.1204 | 30.935 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 65536 | 1 | b1 | all | 5 | 38.528 | 5.33875e+06 | 2.54572 | 0.996683 | 2.55419 | True | False | 5 | 5 | 1 | 1 | False | 38.528 | 5.33875e+06 | 2.54572 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
