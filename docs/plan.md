# 專案計畫與狀態（single source of truth）

> 所有狀態以本檔為準，不依賴對話記憶。每次任務開始／結束、每次 A100 數據回來都要更新「目前狀態」與「任務看板」。
> 最後更新：2026-11-12（T2 gate A100 通過，見 §7、L003）。前一次：2026-11-11 晚（Codex 週額度重置前一次派出 T3/T2b/T4a/T4b/T5a；T1-fix-1 已由 Codex 推到 PR #1 @ dce6093，待 Claude 複審）

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
| T0 | Colab preflight：GPU 型號、nvcc、ncu 安裝與 counter 權限 | 使用者跑 `notebooks/colab_preflight.ipynb`，結果貼回 | ✅ L4 上通過（2026-11-11）；A100 型號待首次正式執行確認 |
| M0 / T1 | 量測工具：bandwidth test、ncu 腳本、三方 sweep（CSV+圖）、VkFFT kernel 匯出。**不改演算法** | Codex | ✅ 2026-11-12 merge（fix-1 @ dce6093 複審通過：pytest 55 passed、shellcheck 乾淨、full dry-run ncu 擷取上限 334 kernels）。L4 quick 冒煙見 `results/smoke_l4_20261111/`。注意：legacy N=2^16 每 batch 另有一次 D2D `cudaMemcpyAsync`（非 kernel，ncu 看不到），分析趟數時要補上 |
| ~~T1b~~ | ~~Colab notebook 包裝~~ → 不需要：改由 Claude 透過 Colab CLI 直接執行（§8） | — | ✖ 取消 |
| T1-run | 在 Colab A100 跑 T1 full，commit `results/<tag>/` | Claude（經 Colab CLI） | ⏳ PR #1 已 merge，等 A100 |
| T1-analysis | 分析：HBM/L2 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 用了幾趟與各自達成率；證實或推翻 F5/F6 | Claude | ⏳ |
| M2 / T2 | 2-pass v1（求正確）：`fft2/` 新 API、numpy 參考模型（CPU 可測）、GPU correctness 測試對 cuFFT。範圍 2^16–2^24 全走 2-pass，不做單 kernel 小 N | Codex | ✅ PR #2 已 merge（L4/G4/A100 gate 通過，見 L003） |
| T2b | 把 `fft2` 接成 `bench/` 的第 4 個 backend + 變體 A/B 腳本（`docs/codex-tasks/T2b-bench-fft2-backend.md`，分支疊在 T1+T2 上） | Codex | ✅ 2026-11-12 merge PR #7（pytest、shellcheck 過；full dry-run ncu 上限 352）。GPU 待確認：NVTX 跳脫、每次 2 kernels、oop 正確性。預設變體檔對 H13 覆蓋不足，A100 改用自訂 tile 清單 |
| T2c | bench／變體腳本加 `--fft2-index-mode`、`--fft2-smem-padding`，讓 H9/H10 能跟 tile sweep 同一次 A100 A/B（`docs/codex-tasks/T2c-bench-fft2-variant-axes.md`） | Codex | 📝 待交給 Codex |
| T3 CI | GitHub Actions：pytest、shellcheck、dry-run、CUDA 13 容器 compile-only（`docs/codex-tasks/T3-ci.md`；只動 `.github/`，目錄不存在時 skip） | Codex | ✅ 2026-11-12 merge PR #3（main 與 T1+T2 整合兩次 run 皆綠） |
| Harness | `scripts/colab/run.sh`：一次 GPU 執行的完整流程，失敗也自動 stop | Claude | ✅ 2026-11-11（CPU runtime 端到端測試） |
| ~~T3~~ | 併入 T2 | — | ✖ |
| T4a | fft2 變體 1：32-bit shift/mask 索引（H9）、shared padding（H10），opt-in，預設輸出不變 | Codex | ✅ 2026-11-12 merge PR #6（預設維持 v1 算式）。整合修正 db09a7a：ncu 名稱檢查接受 template kernel。GPU 待驗：`fft2_test --variants`。bench 尚不能選 index_mode/padding → T2c |
| T4b | fft2 變體 2：register radix-8/16（H11）＋ **H13 附錄**（shared 只做交換、`tile_policy` 佔用率導向，2026-11-12 加），疊在 T4a 上 | Codex | 📝 尚未開始；連同附錄交給 Codex |
| T4c | fft2 變體 3：twiddle 存取（shared 暫存 / 遞推 / 單表 cross twiddle，H12），疊在 T4b 上 | Codex | 📤 T4b 推上去後接著做 |
| T6 | `scripts/a100_session.sh`：一次 A100 allocation 跑完 gate + T1 full + 變體 + 報告，可續跑、有時間預算 | Codex | 📤 2026-11-11 晚；分支已有 commits，尚未開 PR |
| T7 | `fft2/tools/plan_explorer.py`：不靠 GPU 預測 occupancy、coalescing、bank conflict（標為模型預測） | Codex | 📤 2026-11-11 晚；分支已有 commits，尚未開 PR |
| T8 | README 作品集骨架（不含任何數字，留 placeholder 給 T5a 填） | Codex | 📤 2026-11-11 晚；分支已有 commits，尚未開 PR |
| T4.x | A100 一次 allocation A/B 所有變體 → 依 ncu 決定預設值（每項一個 log 條目） | Claude | ⏳ |
| T5a | `make_report.sh`：從 `results/<tag>/` 自動產生瓶頸分析 Markdown（不手打數字） | Codex | ✅ 2026-11-12 merge PR #5。已知缺口：fft2 標籤列被濾掉 → T5a-fix-1 |
| T5a-fix-1 | 報告產生器以 family 比對 impl，保留 `fft2[...]` 各變體（`docs/codex-tasks/T5a-fix-1.md`） | Codex | 📝 待交給 Codex |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Claude | ⏳ |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 7. 目前狀態

- 已讀完 `fft_cuda.cu`、`fft_cuda.h`、`benchmark.cpp`、`profile_stages.cu`、`Makefile`、`results/`。
- 建立本檔、`docs/optimization-log.md`、T1 prompt。
- T1 已交給 Codex（2026-11-11）。平台定為 Colab A100（§8）。
- T0 preflight 在 Colab L4 通過：ncu counter 可用，環境為 CUDA 13.0（見 §8）。
- GPU 執行改走 Colab CLI（§8）。PR #1（T1）已審 + 在 L4 跑 quick 全通過；修正輪 T1-fix-1 已寫好。
- T2（PR #2）L4 gate 通過（2026-11-11，`notebooks/t2_gate.ipynb` Run all）：正確性全過、2 kernels/execute；2^24 b1 pass1 讀取 1.32 趟（校正後）＝ L4 上 C=1 退化所致。
- **2026-11-11 晚**：GPU 是瓶頸，先把不需 GPU 的工作全部派給 Codex（T3、T2b、T4a→T4b→T4c、T5a、T6、T7、T8；T3/T2b/T4a/T5a 已推上 PR #3/#7/#6/#5，分支／目錄互不重疊）。下次 A100 allocation 目標：T2 gate + T1 full + T4 變體 A/B 一次跑完。
- **2026-11-12**：T2 gate 在 **A100-SXM4-40GB 通過**（使用者用另一個帳號連上，Colab UI Run all）。正確性 28/0/1，每次 execute 2 kernels，DRAM 讀 1.00 趟、寫 0.94–0.98 趟。另在 G4（sm_120）通過正確性。見 L003、`results/t2_gate_a100_20261112/`、`results/t2_gate_g4_20261112/`。
- v1 在 A100 上 2^24 b1 合計 3.22 ms，等效頻寬只有 282–408 GB/s。ncu 顯示**佔用率被 shared memory 限在 12.5%**（每 SM 1 block）。
- 2026-11-12：使用者把規劃安排交給 Claude（§8）。Codex 分支已推上：T1（含 fix-1）、T2b、T3、T4a、T5a、T6、T7、T8；T4b、T4c 尚未開始。
- **2026-11-12（續）**：PR #1、#3、#7、#6、#5 全部審完並 merge 進 main（含整合修正 db09a7a）。新開 T2c、T5a-fix-1 兩個小修正 prompt。T6/T7/T8 分支有 commits 但沒開 PR。
- **下一步（Claude 排定，依序）**
  1. merge PR #2（T2）。
  2. 審 + merge，依相依順序：PR #1 T1（複審 fix-1 @ dce6093）→ T3 CI → T2b（疊在 T1+T2 上）→ T4a → T6 → T5a / T7 / T8。每個審查發現就寫成修正 prompt 交給 Codex。
  3. T4b 加上 H13 附錄（`docs/codex-tasks/T4b-fft2-register-radix.md`：register 存資料、shared 只做交換、`tile_policy` 佔用率導向）。T4b 尚未開始，直接連同附錄交給 Codex。
  4. **下次 A100 allocation**（T6 `a100_session.sh`，或在 T6 merge 前用 notebook 手動跑）：T1 full（實測頻寬上限 + cuFFT/VkFFT baseline）＋ T2b sweep 加 `--fft2-tile-cols/--fft2-tile-rows ∈ {1,2,4,8}`。這個 tile sweep 不需新程式就能先驗 H13 ＋ T4a 變體 A/B。
  5. 依 4 的 ncu 數據定調優順序，H13 預期在 H9 之前。
- ~~下一步（2026-11-11 晚）：A100 跑 `notebooks/t2_gate.ipynb` → 通過即 merge PR #2；調優第一項建議 = 內層 64-bit 除法改 32-bit/shift（待 A100 ncu 證實）。~~
- **下一步（舊）**：(1) T1-fix-1 已交給 Codex（推到 PR #1 分支）→ Claude 複審 → merge → A100 跑 T1 full；(2) 平行：T2 prompt 交給 Codex（新分支 `codex/t2-two-pass-v1`，只動 `fft2/`）→ Claude 在 L4/A100 跑 `fft2_test` 驗證正確性。

## 8. 決策紀錄

| 日期 | 決策 | 理由 / 影響 |
|---|---|---|
| 2026-11-11 | 實作由 Codex 負責（使用者有 Codex 額度要用）；使用者貼 prompt | Claude 審 PR、分析數據 |
| 2026-11-11 | **GPU 平台固定為 Google Colab A100**，正式數據只認 `A100-SXM4-40GB` | 與舊數據同型號。每次執行前 notebook 先 assert GPU 名稱，不符就中止、不量。曾評估 gputw.ai（只有 A100 80GB、NT$38.4/hr、當時無現貨），未採用 |
| 2026-11-11 | **GPU 執行改走官方 Colab CLI**（`google-colab-cli` 0.7.5，裝在使用者的 WSL Ubuntu，`--auth oauth2`） | Claude 可自行 `colab new --gpu A100`、`colab upload/exec/download`、`colab stop`；使用者不必開瀏覽器或貼結果。開機前 Claude 先徵得同意；用完立即 stop。費率實測：L4 1.94 單元/hr。A100 當天兩次分配失敗（Bad Gateway / timeout），fallback L4 |
| 2026-11-12 | **使用者把規劃安排交給 Claude**：Claude 決定任務順序、寫與修 Codex prompt、審查與 merge PR、排 GPU 工作 | 使用者仍負責：GPU 花費（開 runtime）、把 prompt 貼給 Codex、審 optimization-log 結論（作品集措辭）。M1 檢查點（是否追 cuFFT）仍與使用者討論 |
| 2026-11-12 | **A100 難分配時，G4（RTX PRO 6000 Blackwell，sm_120）只用來驗正確性**，正式平台仍是 A100-SXM4-40GB；不改用 G4 當正式平台 | G4 的 FP64 很弱，FP64 FFT 在 G4 上推論為計算瓶頸，「% of 實測頻寬上限」的分析不成立。Colab 選單上的 H100 需升級方案，目前不可選。A100 連不到時可換帳號再試 |

### Colab CLI 操作備忘
- 0.7.5 的 `colab ssh -s S -- CMD` 不可用；改用 `colab exec -s S -f script.py`（在 kernel 裡 `subprocess.Popen` 背景執行 shell 腳本），長任務以 `/content/<name>_done` 檔案輪詢完成。
- 程式碼在 runtime 上直接 `git clone` 公開 repo 的分支；結果 `tar` 後 `colab download` 回本機，由 Claude 挑精簡檔案 commit（完整 ncu 報告不進 repo）。

### Colab 對工作流程的影響（原 notebook 方案，保留作備援）
- 執行入口是 notebook（`notebooks/`），使用者開 notebook → Run all → 結果 push 回 GitHub（token 放 Colab Secrets，名稱 `GITHUB_TOKEN`，不寫進 notebook）。
- Colab 磁碟是暫存的：每次跑完 **先 push `results/` 再斷線**。
- 無法鎖頻（`nvidia-smi -lgc` 無權限屬預期），以時脈紀錄 + 多次 trial 中位數代替。
- **最大風險**：Colab 容器內 ncu 能否讀 performance counter。由 `notebooks/colab_preflight.ipynb` 驗證；若不行，核心目標（ncu 達成率）需改平台或改用 CUPTI 以外的替代量測，屆時再討論。

### T0 preflight 結果（2026-11-11，Colab **L4**，A100 當時排不到；原始輸出 `results/preflight/colab_l4_2026-11-11.json`）
- ✅ **ncu 可讀 performance counter**（`ERR_NVGPUCTRPERM` 未出現，`--clock-control none` 可用）。權限取決於 Colab 容器設定而非 GPU 型號，A100 預期相同（A100 首次正式執行時再確認一次）。
- 環境：**CUDA 13.0**（nvcc）、ncu 2025.3.1、Python 3.13、以 root 執行、12 vCPU、52 GB RAM、113 GB 暫存磁碟。
- CUDA 13 影響：
  - 已不支援 sm_61 等舊架構離線編譯 → legacy `Makefile` 預設 `CUDA_ARCH=sm_61` 在 Colab 上會失敗，**一律 `make -B CUDA_ARCH=sm_80`**（不改 legacy Makefile 預設值，只在腳本中傳參數）。
  - CUDA 13 移除了 `cudaDeviceProp` 的部分欄位（如 `clockRate`、`memoryClockRate`）→ T1 的「理論頻寬」需改用 `cudaDeviceGetAttribute` 並容許失敗，或從 `nvidia-smi` 取得。審 T1 PR 時檢查。
  - VkFFT v1.3.4 + CUDA 13 的 NVRTC 相容性未驗證 → T1 首次執行時注意。
- 觀察（L4，不作結論）：2 GiB copy kernel 的 ncu `dram__bytes_read/write` 各 ~2.48 GB，比理想值 2.15 GB 多 ~15%；`lts__t_bytes` 4.30 GB 則與理想值一致。推論：L4 的 GDDR6 inline ECC 等額外 DRAM 流量。→ **ncu 的 DRAM bytes 不能直接除以理想 bytes 當「趟數」，要先用 bwtest copy kernel 在同一台 GPU 上校正**（T1 已規劃 profile bwtest kernel，A100 上再確認比例）。

## 9. 開放問題 / 待使用者決定

1. ~~A100 型號~~ → 已決定：Colab A100-SXM4-40GB。
2. ~~Colab 上 ncu 是否能讀 counter~~ → ✅ 可以（T0，L4）。A100 型號名稱與 counter 權限在第一次 A100 執行時由 notebook 再確認。
3. batched 的定義（預設：N×batch 固定為 2^25 個元素 = 512 MiB，遠超 L2，看 HBM 行為；另加 batch=8 小批次）。可調。
4. T1 的 `run_t1_all.sh` 需要一個 Colab notebook 包裝（clone、build、跑、push）；待 T1 PR 審完後作為 T1b 交給 Codex，或由 Claude 直接寫（檔案很小）。
