# Per-kernel profile

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_id | kernel | grid | block | registers_per_thread | static_smem_bytes | dynamic_smem_bytes | smem_bytes | duration_us | pct_config_time | dram_read_bytes | dram_write_bytes | lts_bytes | dram_GBs | pct_measured_hbm_copy | l2_GBs | pct_measured_l2_copy | theoretical_occupancy_pct | achieved_occupancy_pct | shared_bank_conflicts_ld | shared_bank_conflicts_st | fp64_pipe_util_pct | stall_1 | stall_1_pct | stall_2 | stall_2_pct | stall_3 | stall_3_pct | pct_mixed_hbm_limit | pct_l2_limit | l2_limit_method | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 7778:1:13:0 | transpose_opt | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 19.552 | 10.6427 | 1.67831e+07 | 2.64282e+06 | 6.13028e+07 | 993.552 | 72.9076 | 3135.37 | 109.701 | 100 | 71.5 | 19073 | 9090 | 0 | mio_throttle | 32.74 | lg_throttle | 26.97 | long_scoreboard | 17.84 | 67.9879 | 114.385 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 7778:1:13:1 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.904 | 32.6076 | 1.67991e+07 | 875904 | 6.35703e+07 | 295.056 | 21.6514 | 1061.2 | 37.1295 | 37.5 | 35.05 | 526276 | 1.444e+06 | 13.78 | mio_throttle | 35.11 | long_scoreboard | 17.76 | barrier | 16.05 | 20.243 | 38.7149 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 7778:1:13:2 | transpose_and_twiddle | (32, 32, 1) | (32, 8, 1) | 32 | 16896 | 0 | 16896 | 20.608 | 11.2176 | 1.67933e+07 | 2.46426e+06 | 5.97844e+07 | 934.472 | 68.5723 | 2901.03 | 101.502 | 100 | 79.04 | 18387 | 7602 | 37.57 | mio_throttle | 26.91 | long_scoreboard | 13.92 | lg_throttle | 13.62 | 63.9607 | 105.836 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 7778:1:13:3 | fft_block_1024_specialized | (1024, 1, 1) | (256, 1, 1) | 78 | 16896 | 0 | 16896 | 59.424 | 32.3463 | 1.67991e+07 | 466176 | 6.3761e+07 | 290.544 | 21.3203 | 1072.98 | 37.5417 | 37.5 | 35.04 | 526231 | 1.44386e+06 | 13.83 | mio_throttle | 35.04 | long_scoreboard | 16.52 | barrier | 16.3 | 19.947 | 39.1448 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |
| legacy |  | 1048576 | 1 | b1 | all | 7778:1:13:4 | transpose_square_inplace | (32, 32, 1) | (32, 8, 1) | 62 | 33792 | 0 | 33792 | 24.224 | 13.1859 | 1.67814e+07 | 657280 | 6.35332e+07 | 719.894 | 52.8264 | 2622.74 | 91.7647 | 50 | 38.58 | 13670 | 6593 | 0 | mio_throttle | 29.8 | lg_throttle | 25.71 | long_scoreboard | 24.6 | 49.4078 | 95.6831 | total_lts_bytes/read_plateau | True | False | 5 | 5 | 1 | 1 |

DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics.

L2 limit method: total LTS bytes divided by the measured L2 read plateau; no read/write sector split is inferred.

Complete capture: 5 kernel launches; totals are measured, not extrapolated.

Config totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):

| impl | impl_detail | N | batch | batch_mode | cache_control | kernel_count | total_time_us | total_dram_bytes | effective_memory_passes | dram_copy_traffic_factor | calibrated_memory_passes | working_set_fits_l2 | sampled | captured_kernels | expected_kernels | sampling_ratio | extrapolation_factor | totals_extrapolated | captured_time_us | captured_dram_bytes | captured_effective_memory_passes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| legacy |  | 1048576 | 1 | b1 | all | 5 | 183.712 | 9.10625e+07 | 2.71387 | 0.99669 | 2.72289 | True | False | 5 | 5 | 1 | 1 | False | 183.712 | 9.10625e+07 | 2.71387 |

Legacy copy-normalized percentages are retained. pct_mixed_hbm_limit adds read/write service times at their separately measured peaks; pct_l2_limit uses the measured read plateau. NCU replay durations are distinct from unprofiled sweep times.
