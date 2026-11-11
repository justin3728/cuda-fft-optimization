# T2 gate — Colab L4 (sm_89), 2026-11-11

Source: `notebooks/t2_gate.ipynb`, branch `codex/t2-two-pass-v1` @ 87597e8. Owner ran "Run all"; output pasted to Claude.
**L4 = smoke test only (not the target GPU). Timings below are not performance results.**

## Correctness gate (`fft2/fft2_test`)
```
build: OK
fft2_test exit: 0
SUMMARY passed=28 failed=0 skipped=1 api=PASS
  skip -> N=16777216 batch=8   (memory cap, expected)
rel_l2 range: 4.52e-16 .. 6.05e-16  (gate 1e-12)
```
27 default configs + 2 custom split/tile configs (one skipped), out-of-place and in-place, vs cuFFT Z2Z.

## ncu (one `execute()`, `--clock-control none`, default cache control)
Ratios are DRAM bytes / (16·N·batch). L4 copy-kernel calibration = 1.15x (L001), so 1.15x ≈ exactly one pass.

| config | kernel | read | write | time (µs) | eff BW (GB/s) |
|---|---|---:|---:|---:|---:|
| 2^24 b1 | pass1_columns | 1.52x | 1.15x | 7167.2 | 100 |
| 2^24 b1 | pass2_rows | 1.15x | 1.15x | 5939.3 | 104 |
| 2^22 b8 | pass1_columns | 1.16x | 1.15x | 12363.6 | 100 |
| 2^22 b8 | pass2_rows | 1.11x | 1.17x | 10907.8 | 113 |

- Exactly 2 kernels per `execute()` in both configs (the notebook's FAIL verdict was a name-matching bug in the notebook: ncu reports `(anonymous namespace)::pass1_columns`; fixed after this run).
- L4 measured limits (`results/smoke_l4_20261111/bandwidth/limits.json`): read 260, copy 243 GB/s.
