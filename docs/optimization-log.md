# Optimization Log

每個條目固定格式：**假設 → 量測（ncu / sweep 數據，附 results 路徑）→ 結果（證實／推翻／部分）→ 下一步**。
失敗、推翻、沒有變快的嘗試也要記。數字只引用 `results/` 裡已 commit 的檔案；推論標「推論」。

量測慣例（T1 後生效）：
- 「上限」= `results/<tag>/bandwidth/` 的實測值，不用規格表數字。
- 每個 kernel 報：`gpu__time_duration`、DRAM bytes（讀/寫）、L2 bytes、達成頻寬、% of 實測 HBM 上限、% of 實測 L2 上限、achieved occupancy、shared bank conflicts、主要 stall reason。
- ncu 預設 `--cache-control all`（每個 kernel 前清 cache）與 `--clock-control base`（鎖在 base clock）；兩者都會讓結果和 benchmark 不同，條目中要註明用的設定。

---

## L000 — 2026-11-11 — 讀碼診斷（無新數據）

**來源**：讀 `fft_cuda.cu`、`benchmark.cpp`；既有數據 `results/benchmark_results.csv`、`results/stage_profile.txt`（A100-SXM4-40GB, CUDA 12.8）。

**既有數據（舊 harness，見 plan.md F2 的方法學疑慮）**
| N=2^20 | 時間 |
|---|---|
| legacy device | 0.1835 ms |
| cuFFT device | 0.1277 ms |
| stage: transpose_opt | 29.8 µs |
| stage: row FFT 1024 ×2 | 61.6 µs 各 |
| stage: transpose_and_twiddle | 23.3 µs |
| stage: transpose_square_inplace | 22.4 µs |

推論：transpose 一趟搬 32 MiB / ~22–30 µs ≈ 1.1–1.5 TB/s，量級接近 HBM 規格；row FFT 同樣一趟卻要 ~62 µs，約慢 2–3 倍 → row FFT kernel 不是 memory-bound，是指令／latency／shared memory 受限。

**假設（皆待 T1 ncu 證實）**
- H1：row FFT 1024 kernel 有顯著 shared memory bank conflict（bit-reverse scatter 寫入、stride 存取、無 padding）。
- H2：row FFT 1024 kernel 的 achieved occupancy 偏低（~37%，78 regs × 256 threads，`__launch_bounds__(256,2)`），且 5 次 `__syncthreads` 造成 barrier stall。
- H3：twiddle 以 `__ldg` 從 global 讀（每 butterfly 3 次），增加 L1/LSU 壓力。
- H4：`transpose_and_twiddle` 的 FP64 `sincos` 使它比純 transpose 慢（stage 數據 23.3 vs 22.4/29.8 µs 不支持這點 —— 待 ncu 看 FP64 pipe 利用率）。
- H5：2^20 時 working set（data+temp = 32 MiB）可能落在 L2，legacy 各 stage 的實際瓶頸可能是 L2 而非 HBM。
- H6：cuFFT 在 2^20 用的趟數 < 5（推論 2–3 趟），且未達頻寬上限（128 µs 對比估計下限 ~45–50 µs）。

**結果**：尚無。由 T1 量測工具驗證。

**下一步**：T1（`docs/codex-tasks/T1-measurement-tooling.md`）。
