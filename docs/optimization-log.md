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

---

## L002 — 2026-11-11 — T2 2-pass v1 正確性 gate（Colab **L4**，非目標 GPU）（**草稿，待使用者審閱**）

**來源**：PR #2 @ 87597e8，`notebooks/t2_gate.ipynb`，`results/t2_gate_l4_20261111/summary.md`。

**結果**
- 正確性：28 passed / 0 failed / 1 skip（2^24 b8，記憶體上限），out-of-place 與 in-place 對 cuFFT rel L2 4.5e-16–6.1e-16（gate 1e-12）。
- 結構：ncu 確認每次 `execute()` 恰 2 個 kernel（2^24 b1、2^22 b8）。
- 流量（除以 L4 校正 1.15）：除了 2^24 b1 pass 1 讀取 ≈1.32 趟，其餘 ≈1.0 趟 → 「2 趟」結構成立。

**解讀（假設，待 A100 證實）**
- H7：2^24 b1 pass 1 多出的 ~0.3 趟讀取來自 L4 的 C=1 退化（每列只取 16 B，32 B sector 一半浪費，鄰 column 的 block 未必在 L2 命中）。A100 該設定 C=2，預期消失。2^22 b8（L4 C=2）讀取 1.16x 支持此點。
- H8：L4 上只達 copy 上限的 41–47%（100–113 / 243 GB/s）。可能原因：L4 FP64 極弱、內層 64-bit 整數除法、A100 上的低 occupancy（每 block 128 KiB shared → 1 block/SM）。L4 數字不作結論。

**下一步**：A100 跑同一個 notebook；通過 → merge PR #2 → 依 ncu 排調優（候選第一項：block_fft/載入迴圈的 64-bit `/`、`%` 改 32-bit shift）。

---

## L003 — 2026-11-12 — T2 2-pass v1 正確性 gate（**A100-SXM4-40GB**；另有 G4 正確性）（**草稿，待使用者審閱**）

**來源**：PR #2 @ 87597e8，`notebooks/t2_gate.ipynb`（使用者在 Colab UI 執行 Run all，輸出貼回）。結果在 `results/t2_gate_a100_20261112/summary.md` 和 `results/t2_gate_g4_20261112/summary.md`。ncu 設定一律 `--clock-control none`，cache control 用預設值。

**結果**
- 正確性（A100）：28 passed / 0 failed / 1 skip（2^24 b8，測試自設的記憶體上限）。rel L2 4.5e-16–6.1e-16（門檻 1e-12）。
- 正確性（G4，sm_120）：28 / 0 / 1，以 `-Werror` 零警告編譯。G4 只作正確性證據（plan §8，2026-11-12）。
- 結構：A100 上兩組設定都是每次 execute 恰好 2 個 kernel。
- 流量（A100 的 DRAM 校正尚未量，以原始比值計）：每個 kernel 讀 1.00 趟、寫 0.94–0.98 趟 → 「2 趟」結構成立，**沒有多餘流量**。
- **H7 證實**：L4 上 2^24 b1 pass1 多讀的約 0.3 趟，在 A100 上消失（讀 1.00x，grid 2048 → C=2）。
- 時間（2^24 b1）：pass1 1866.9 µs + pass2 1349.8 µs = 3.22 ms。等效頻寬 282 / 387 GB/s。2^22 b8 為 301 / 408 GB/s。
- 佔用率（2^24 b1）：兩個 kernel 都是 shared memory 135.17 KB/block → **每 SM 1 block，理論 12.5%、實際 12.47–12.48%**。register 34–38/thread，本來可容 6 blocks。warp cycles per issued instruction 9.4–10.5。

**解讀（推論，待證）**
- H8 修正：v1 慢的主因推論是**佔用率太低、無法隱藏記憶體延遲**。每 SM 只有 8 warps，每個 scheduler 2 個 warp，每 ~10 cycle 才發出一個指令 → latency-bound。它不是頻寬瓶頸（約 20–25% of 規格 HBM；實測上限待 T1），也不是 FP64 瓶頸（約 0.63 TFLOP/s ≈ 規格的 6%）。
- 旁證：G4 的 FP64 比 A100 弱很多，但同一設定時間幾乎一樣（G4 3.39 ms vs A100 3.22 ms）→ 時間不由 FP64 算力決定。
- 若達到頻寬上限，2^24 b1 約 0.75–0.8 ms（以規格 1.55 TB/s 估），還有約 4 倍空間。上限數字待 T1 實測取代。
- 64-bit 除法（H9）仍可能有影響，但在 12.5% 佔用率下，它很可能不是第一順位。

**下一步（待使用者決定）**
- 新假設 **H13**：降低每個 block 的 shared memory 用量（例如 data 改放 register、shared 只做交換用，或縮小 tile），讓每 SM ≥ 2–4 blocks，達成頻寬會明顯上升。目前 T4a–c 都沒有直接處理這一點。T4b（register radix）可能順帶降低 shared 需求，要看實作。
- 建議：在 T4b 的驗收標準加入「shared memory/block 與 blocks/SM」，或另開一個 T4d 專門處理 H13。
- A100 跑 T1 full，取得實測 HBM/L2 上限與 cuFFT/VkFFT baseline，「% of 上限」才有分母。

## L004 — 2026-11-12 — 合併後工具冒煙測試 + H13 tile sweep 縮小版（Colab **L4**，非目標 GPU）（**草稿，待使用者審閱**）

**來源**：main @ f20c70e（已 merge PR #1/#3/#5/#6/#7）。Claude 經 SSH 在 L4 執行，`CUDA_ARCH=sm_89`。精簡結果在 `results/smoke_t1_l4_quick_20261112/` 和 `results/smoke_h13_l4_20261112/`。ncu 設定為 `--clock-control none`、`--cache-control all`。**L4 數字只作冒煙測試，不是正式數據。**

**工具驗證（全部通過）**
- `fft2_test --variants`（T4a gate）：146 passed / 0 failed / 28 skipped，含編譯共 46 s。6 個變體軸都有覆蓋。
- `run_t1_all.sh --quick`（含 fft2）：7 個階段全 OK，共約 2.7 min。fft2 sweep 列全部 `ok`，rel L2 ≤ 6.1e-16。
- T2b 待 GPU 確認的項目：NVTX 跳脫可用，每個 fft2 設定恰好抓到 2 個 kernel；template kernel 名稱檢查（db09a7a）正常。
- `run_fft2_variants.sh --ncu`：從頭到尾跑通，5 個變體 × 2 尺寸 × 2 batch 的 sweep 列全部 `ok`。
- 待分析時處理：L2-resident 設定中，`pct_mixed_hbm_limit` 有 101–108%（legacy transpose、bwcopy）；`pct_l2_limit` 有 103–126%（cache none）。已知原因是 L2 延後寫回，以及 L2 上限只用 read plateau 估。正式判讀以 A100 為準。

**H13 tile sweep（L4，auto split，C = R = k）**

| N, batch | k=8（=auto） | k=4 | k=2 | k=1 |
|---|---|---|---|---|
| 2^18 b1，hot 中位數 | 229.4 µs | 156.8 | 132.7 | **118.4** |
| 2^18 b128，hot 中位數 | 20.53 ms | **16.21** | 16.94 | 17.85 |
| 2^16 b512，hot 中位數 | 14.74 ms | **14.54** | 15.30 | 16.88 |
| 2^18 b1 ncu：smem/block、理論佔用率 | 64 KiB、16.7% | 32 KiB、50% | 16 KiB、83% | 8 KiB、100% |
| 2^18 b1 ncu：pass1 + pass2 | 257.7 µs | 182.7 | 161.0 | 137.3 |

**解讀（推論，待 A100 證實）**
- 降低 shared memory 用量確實提高了佔用率，b1 時間也跟著下降，方向與 H13 一致。
- 但 b1 的改善混了另一個因素：auto 在 2^18 b1 時，每個 pass 只有 64 個 block，L4 有 58 個 SM，連一個完整 wave 都填不滿。k=1 時有 512 個 block。所以 b1 的加速不能全部歸給佔用率。
- batched（block 數夠多）時，最佳點在 k=4，不是 k=1。k=1 在 2^16 b512 時比 auto 慢 15%。推論：C 越小，pass1 每次跨行讀取的連續 bytes 越少（C=1 時只有 16 B），sector 利用率下降。**佔用率和合併存取之間有取捨**，所以 `tile_policy` 不能只追佔用率。
- 因此 A100 tile sweep 必須涵蓋 2^24（DRAM-bound，auto C=2 → 1 block/SM）和 batched 設定，並看 DRAM sector 效率（例如 `dram__bytes_read` 對理想值的比例）。
