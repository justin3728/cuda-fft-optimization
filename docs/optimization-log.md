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

---

## L001 — 2026-11-11 — T1 工具冒煙測試（Colab **L4**，非目標 GPU）

**來源**：PR #1 @ 39d1b96，`run_t1_all.sh --quick`，`results/smoke_l4_20261111/`。L4 = Ada sm_89、GDDR6、L2 48 MB、FP64 極弱 → **只用來驗證工具，數字不作效能結論**。

**工具驗證結果**：7 個階段全 OK；CUDA 13 編譯零警告；三個實作 rel L2 err ≤ 7.2e-16；VkFFT 正負號與 cuFFT 一致；NVTX 過濾抓到 legacy 5 / cuFFT 2 / VkFFT 2 個 kernel（N=2^20）。

**方法學發現（影響之後所有分析）**
- 2^20 的 16 MiB 輸出會留在 L2，kernel 結束後才寫回 DRAM → 單一 kernel 的 `dram__bytes_write` 幾乎為 0，`% of HBM copy limit` 會出現 >100%（transpose_opt 115%）。2^20 這類 working set ≤ L2 的設定，**必須以 L2 指標判斷**，DRAM 指標只適用 working set ≫ L2。→ T1-fix-1 F2。
- copy kernel 校正：L4 上 DRAM bytes / 理想 = 1.15（WS 4 GiB），lts bytes / 理想 = 1.00。A100 需重量。

**對 L000 假設的初步跡象（L4，待 A100 證實）**
| 假設 | L4 ncu 觀察（legacy `fft_block_1024_specialized`, N=2^20） |
|---|---|
| H1 bank conflict | shared ld 衝突 524,288、st 衝突 1,441,792（每次呼叫）→ 有，且 store 側更嚴重（bit-reverse scatter 寫入嫌疑大） |
| H2 occupancy | 理論 50%、實際 47.3%（78 regs × 256 threads） |
| H3 twiddle 從 global 讀 | 首要 stall = `tex_throttle` 59%（`__ldg` 走 texture path）→ 支持 |
| barrier | 第二大 stall `barrier` 13.5% |

**下一步**：T1-fix-1 → A100 full run → 正式 T1-analysis。
