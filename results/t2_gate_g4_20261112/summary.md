# T2 gate — Colab G4 (sm_120, CC 12.0), 2026-11-12

Source: `notebooks/t2_gate.ipynb` (pre-fix version), branch `codex/t2-two-pass-v1` @ 87597e8. Owner ran "Run all"; output pasted to Claude.
**G4 is not the target GPU, and its FP64 throughput is a small fraction of A100's. Treat this run as correctness evidence only; the timings below are not performance results.**

## Correctness gate (`fft2/fft2_test`)
```
N=16777216 batch=8 SKIP memory_cap minimum_device_bytes=6459228160 device_cap=6442450944 host_bytes=2164260864 host_cap=2147483648
SUMMARY passed=28 failed=0 skipped=1 api=PASS
```
- The build used `-arch=sm_120 -Werror=all-warnings -Xcompiler=-Wall,-Wextra,-Werror` and succeeded.
- The skip comes from the test's own 6 GiB device / 2 GiB host cap, not from the GPU's memory.
- The rel_l2 range was not captured. `failed=0` means every config is ≤ 1e-12.

## ncu (2^24 b1, one `execute()`, `--clock-control none`)
| kernel | grid × block | time (µs) |
|---|---|---:|
| pass1_columns | 4096 × 256 | 1823.3 |
| pass2_rows | 4096 × 256 | 1566.5 |

- Each `execute()` launches exactly 2 kernels.
- The grid is 4096 here versus 2048 on A100. The plan picks a smaller column tile because G4's opt-in shared-memory limit per block is lower.
- `dram__bytes_read.sum` / `dram__bytes_write.sum` report `n/a` on sm_120. The available names are `dram__bytes_op_read` / `dram__bytes_op_write` (from `ncu --query-metrics`).
- The old notebook crashed parsing `n/a` before the 2^22 b8 config and the verdict cell. The notebook is now fixed: it picks whichever metric names exist and skips `n/a`.
