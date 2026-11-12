# 歷史紀錄（唯讀）

> 2026-11-12 從 `docs/plan.md` §6、§7 原文搬來，保留當時的看板與流水帳。現況看 `docs/STATUS.md`，之後不再更新本檔的這兩段；新的里程碑可往下追加。

## 任務看板（截至 2026-11-12 拆檔前）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T0 | Colab preflight：GPU 型號、nvcc、ncu 安裝與 counter 權限 | 使用者跑 `notebooks/colab_preflight.ipynb`，結果貼回 | ✅ L4 上通過（2026-11-11）；A100 型號待首次正式執行確認 |
| M0 / T1 | 量測工具：bandwidth test、ncu 腳本、三方 sweep（CSV+圖）、VkFFT kernel 匯出。**不改演算法** | Codex | ✅ 2026-11-12 merge（fix-1 @ dce6093 複審通過：pytest 55 passed、shellcheck 乾淨、full dry-run ncu 擷取上限 334 kernels）。L4 quick 冒煙見 `results/smoke_l4_20261111/`。注意：legacy N=2^16 每 batch 另有一次 D2D `cudaMemcpyAsync`（非 kernel，ncu 看不到），分析趟數時要補上 |
| ~~T1b~~ | ~~Colab notebook 包裝~~ → 不需要：改由 Claude 透過 Colab CLI 直接執行（§8） | — | ✖ 取消 |
| T1-run | 在 Colab A100 跑 T1 full，commit `results/<tag>/` | Claude（經 Colab CLI） | ✅ 2026-11-12 A100 完成（L005） |
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

## 狀態流水帳（截至 2026-11-12 拆檔前）

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
- **2026-11-12 L4 冒煙（L004）**：merge 後的工具全部在 GPU 上跑通（fft2_test --variants、T1 quick 含 fft2、變體 runner + ncu）。H13 縮小版顯示佔用率與合併存取有取捨，batched 最佳 k=4。使用 1.24 單位。下一步：A100（T1 full + H13 tile sweep，含 2^24 與 batched）。
- **2026-11-12 A100（L005，草稿）**：T1 full + H13 sweep 完成，`results/t1_a100_20261112/`、`results/h13_a100_20261112/`。實測 HBM copy 1363 GB/s、L2 copy 2858 GB/s。cuFFT 2^23–24 用 3 趟、每趟約 88%。fft2 v1 是 cuFFT 的 1.2–2.9 倍時間。H13 在 2^18–2^22 證實（k=2 最佳，最多快 1.87 倍），在 2^24 不成立 → 下一步：tile_policy 小改 + T4b（register radix）。
- **下一步（Claude 排定，依序）**
  1. merge PR #2（T2）。
  2. 審 + merge，依相依順序：PR #1 T1（複審 fix-1 @ dce6093）→ T3 CI → T2b（疊在 T1+T2 上）→ T4a → T6 → T5a / T7 / T8。每個審查發現就寫成修正 prompt 交給 Codex。
  3. T4b 加上 H13 附錄（`docs/codex-tasks/T4b-fft2-register-radix.md`：register 存資料、shared 只做交換、`tile_policy` 佔用率導向）。T4b 尚未開始，直接連同附錄交給 Codex。
  4. **下次 A100 allocation**（T6 `a100_session.sh`，或在 T6 merge 前用 notebook 手動跑）：T1 full（實測頻寬上限 + cuFFT/VkFFT baseline）＋ T2b sweep 加 `--fft2-tile-cols/--fft2-tile-rows ∈ {1,2,4,8}`。這個 tile sweep 不需新程式就能先驗 H13 ＋ T4a 變體 A/B。
  5. 依 4 的 ncu 數據定調優順序，H13 預期在 H9 之前。
- ~~下一步（2026-11-11 晚）：A100 跑 `notebooks/t2_gate.ipynb` → 通過即 merge PR #2；調優第一項建議 = 內層 64-bit 除法改 32-bit/shift（待 A100 ncu 證實）。~~
- **下一步（舊）**：(1) T1-fix-1 已交給 Codex（推到 PR #1 分支）→ Claude 複審 → merge → A100 跑 T1 full；(2) 平行：T2 prompt 交給 Codex（新分支 `codex/t2-two-pass-v1`，只動 `fft2/`）→ Claude 在 L4/A100 跑 `fft2_test` 驗證正確性。
