# 專案計畫與狀態（single source of truth）

> 所有狀態以本檔為準，不依賴對話記憶。每次任務開始／結束、每次 A100 數據回來都要更新「目前狀態」與「任務看板」。
> 最後更新：2026-11-11（平台定為 Colab A100；新增 T0 preflight）

## 1. 目標

| 層級 | 內容 |
|---|---|
| 核心 | 能用數據回答「你怎麼知道它算快」：每個 kernel 以 Nsight Compute 量出相對 **實測** HBM / L2 頻寬上限的達成率，並解釋剩下的差距 |
| 架構 | FP64 C2C FFT 重構為 **2-pass**（N = N1×N2，兩趟全域記憶體讀寫，無獨立 transpose） |
| 延伸 | 限定條件（A100、FP64 C2C forward、N = 2^16–2^24、batch 1 與 batched）下超過 cuFFT |
| Baseline | 舊實作（legacy）、cuFFT、VkFFT（CUDA backend，亦作設計參考） |

### 第一個里程碑（M1）完成定義
1. 2-pass 實作涵蓋 N = 2^16–2^24、batch 1 與 batched，數值對 cuFFT 通過容差。
2. 量測完整：bandwidth 上限、三方（+新實作）sweep、每個 kernel 的 ncu 達成率表。
3. README 有瓶頸分析（每個 kernel：時間、bytes、% of 實測峰值、剩餘差距原因）與 before/after。
4. 達成後 **停下來與使用者討論** 是否追 cuFFT。

## 2. 分工與工作流程

- **Claude（指揮）**：拆任務、寫 Codex prompt（含驗收標準）→ `docs/codex-tasks/`；審 PR；分析 A100 數據；更新本檔與 `optimization-log.md`。
- **Codex**：實作。沒有 GPU，只能保證「能編譯 + 非 GPU 部分的測試通過」。
- **使用者**：貼 prompt、在 A100 上跑 `scripts/` 的一鍵腳本、commit 結果到 `results/`、做方向決定。
- **真相來源**：「算得對、變得快」只以 A100 上的實測為準。Codex 與 Claude 的推論一律標記為「假設」，直到有數據。

循環：任務 prompt → Codex PR → Claude 審 → merge → 使用者在 A100 跑 → commit `results/<tag>/` → Claude 分析、寫 log、更新計畫 → 下一個任務。

## 3. 規則

1. legacy 實作保留為可選 baseline 路徑，**數值輸出不得改變**（`fft_cuda.cu` 的 kernel 與 dispatch 不動；若必須動 API 介面，以 wrapper 包，不改 kernel）。
2. 每次改動在 `docs/optimization-log.md` 記「假設 → ncu 數據 → 結果」，失敗也記。
3. 狀態只寫在本檔。
4. 程度上限見 M1；達成後討論再繼續。

## 4. 現況診斷（讀碼結果 + 上一個 session，未經 ncu 證實者標「待證」）

### 4.1 legacy 管線（N = 2^20, R = C = 1024）
`transpose → row FFT(1024) → transpose+twiddle → row FFT(1024) → in-place transpose` = 5 趟全域記憶體讀寫。
上次 event 計時（`results/stage_profile.txt`）：row FFT 各 ~61.6 µs，transpose 各 ~22–30 µs，總和 ~199 µs；cuFFT 128 µs。

### 4.2 讀碼新發現（2026-11-11）
| # | 發現 | 影響 |
|---|---|---|
| F1 | legacy **只支援 N ≤ 2^20**：row kernel 的 shared array 只有 1024+32 個元素、twiddle table 只有 1024 點；N=2^21 時 C=2048 會越界。`benchmark.cpp` 的 `MAX_LOG_N = 20`。 | 2^21–2^24 legacy 欄位只能是 N/A，該範圍 baseline 只有 cuFFT / VkFFT |
| F2 | 現有 benchmark 每次計時前都做一次 H2D（16 MiB @2^20），且每次只計一次 execution 的 event pair | 資料可能部分熱在 L2（40 MB）；單次 ~0.1 ms 的 event 計時含 launch 抖動。CSV 中 2^14 cuFFT 出現 149% 異常值即為徵兆。**舊數字只作參考，需用新 harness 重建 baseline** |
| F3 | batch 為 host `for` 迴圈，且所有 batch 共用一個 `temp_device` | batched 的 kernel 數 = 5×batch，無法吃滿 GPU；新設計 batch 應是 grid 維度 |
| F4 | `fft_plan_cuda_1d` 在建 plan 時做 host copy + H2D | 規劃與資料移動耦合；新 API 需分離 plan / execute(in, out, stream) |
| F5 | 1024 點 kernel：256 threads、每 thread 每階段 1 個 radix-4、5 階段各一次 `__syncthreads` + shared 往返；載入時以 bit-reverse 位址寫 shared；shared 沒有 padding；每個 butterfly 3 次 `__ldg` 讀 twiddle；78 regs/thread、16.9 KB smem | 疑似 bank conflict、barrier 過多、twiddle 讀取成本（待證：ncu `l1tex__data_bank_conflicts_pipe_lsu_mem_shared`、achieved occupancy、stall reasons） |
| F6 | `transpose_and_twiddle` 每個元素做一次 FP64 `sincos` | FP64 sincos 指令數不小，可能使該 kernel 偏離純頻寬上限（待證） |
| F7 | 奇數次方 N（R≠C）多一次 D2D copy，且最後 transpose 是 out-of-place | 多 1 趟 |

### 4.3 粗估下限（**公式估計，不得當結論**；以 Task 1 實測取代）
- 2^20 FP64 complex = 16 MiB；一趟（讀+寫）= 32 MiB。
- 若 HBM 實測 ~1.3–1.5 TB/s（40GB SXM 理論 1.555 TB/s）：一趟 ≈ 22–26 µs → 2-pass 下限 ≈ 45–50 µs；legacy 184 µs ≈ 7–8 趟等效。
- 但 2^20 的 data+temp = 32 MiB < 40 MB L2，**實際上限可能是 L2 而非 HBM**，A100 L2 又分兩個 partition，必須實測不同 working set 的曲線。
- FP64 計算：5·N·log2N = 105 MFLOP，以 9.7 TFLOP/s 計 ≈ 11 µs，遠小於記憶體時間 → 預期 memory-bound（但 twiddle 計算與 shared 指令開銷待證）。

## 5. 目標架構（草案，M2 前會再細化）

- **新 API**：`plan(N, batch, layout)` 只做 plan（twiddle 表、workspace 大小、kernel 選擇），`execute(in, out, stream)`；batch 是 grid 維度；不做 host 端資料搬移。
- **單 kernel**：N ≤ 2^12（或 shared memory 容得下的上限，A100 每 block 最多 ~163 KB）整個 FFT 在一個 block 內完成。
- **2-pass**（2^13–2^24）：N = N1 × N2，N1、N2 ≤ 4096（2^24 = 4096×4096）。
  - Pass 1：對 stride 方向做長度 N1 的 FFT，每個 block 同時處理數個相鄰欄以合併存取，結尾乘上 cross twiddle（twiddle 用表或遞推，待 ncu 決定）。
  - Pass 2：長度 N2 的連續 FFT，輸出經 shared memory 重排成自然順序（取代 transpose）。
  - 每個 thread 在 register 內做 radix-8/16 子 FFT，減少 shared 往返與 barrier。
- **設計參考**：VkFFT 生成的 kernel（Task 1 (d) 匯出原始碼）。
- legacy 路徑以 `--impl legacy` 選擇，永遠保留。

## 6. 里程碑與任務看板

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T0 | Colab preflight：GPU 型號、nvcc、ncu 安裝與 counter 權限 | 使用者跑 `notebooks/colab_preflight.ipynb`，結果貼回 | ⏳ 可立即執行 |
| M0 / T1 | 量測工具：bandwidth test、ncu 腳本、三方 sweep（CSV+圖）、VkFFT kernel 匯出。**不改演算法** | Codex | 🔨 已交給 Codex（2026-11-11），等 PR |
| T1b | Colab notebook 包裝 `run_t1_all.sh`（clone/build/run/push） | Codex 或 Claude | ⏳ T1 審完後 |
| T1-run | 在 Colab A100 跑 T1，commit `results/<tag>/` | 使用者 | ⏳ 等 T1 + T1b merge |
| T1-analysis | 分析：HBM/L2 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 用了幾趟與各自達成率；證實或推翻 F5/F6 | Claude | ⏳ |
| M2 / T2 | 新 API 骨架 + correctness 測試（對 cuFFT，全 N/batch）+ 單 kernel 小 N | Codex | ⏳ 待 T1 數據後撰寫 |
| T3 | 2-pass 實作（第一版求正確，標準 radix） | Codex | ⏳ |
| T4.x | 依 ncu 數據逐項調優（每項一個 log 條目） | Codex / Claude | ⏳ |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Claude | ⏳ |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 7. 目前狀態

- 已讀完 `fft_cuda.cu`、`fft_cuda.h`、`benchmark.cpp`、`profile_stages.cu`、`Makefile`、`results/`。
- 建立本檔、`docs/optimization-log.md`、T1 prompt。
- T1 已交給 Codex（2026-11-11）。平台定為 Colab A100（§8）。
- **下一步**：(1) 使用者在 Colab A100 跑 `notebooks/colab_preflight.ipynb`，把最後一格的摘要貼回；(2) Codex 開 T1 PR 後交給 Claude 審。

## 8. 決策紀錄

| 日期 | 決策 | 理由 / 影響 |
|---|---|---|
| 2026-11-11 | 實作由 Codex 負責（使用者有 Codex 額度要用）；使用者貼 prompt | Claude 審 PR、分析數據 |
| 2026-11-11 | **GPU 平台固定為 Google Colab A100**，正式數據只認 `A100-SXM4-40GB` | 與舊數據同型號。每次執行前 notebook 先 assert GPU 名稱，不符就中止、不量。曾評估 gputw.ai（只有 A100 80GB、NT$38.4/hr、當時無現貨），未採用 |

### Colab 對工作流程的影響
- 執行入口是 notebook（`notebooks/`），使用者開 notebook → Run all → 結果 push 回 GitHub（token 放 Colab Secrets，名稱 `GITHUB_TOKEN`，不寫進 notebook）。
- Colab 磁碟是暫存的：每次跑完 **先 push `results/` 再斷線**。
- 無法鎖頻（`nvidia-smi -lgc` 無權限屬預期），以時脈紀錄 + 多次 trial 中位數代替。
- **最大風險**：Colab 容器內 ncu 能否讀 performance counter。由 `notebooks/colab_preflight.ipynb` 驗證；若不行，核心目標（ncu 達成率）需改平台或改用 CUPTI 以外的替代量測，屆時再討論。

## 9. 開放問題 / 待使用者決定

1. ~~A100 型號~~ → 已決定：Colab A100-SXM4-40GB。
2. Colab 上 ncu 是否能讀 counter → 待 preflight 結果。
3. batched 的定義（預設：N×batch 固定為 2^25 個元素 = 512 MiB，遠超 L2，看 HBM 行為；另加 batch=8 小批次）。可調。
4. T1 的 `run_t1_all.sh` 需要一個 Colab notebook 包裝（clone、build、跑、push）；待 T1 PR 審完後作為 T1b 交給 Codex，或由 Claude 直接寫（檔案很小）。
