# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-12（L003/L005/L006 與 T4d 預設值經使用者核可；PR #14 第 2 輪 CI 綠、review 無發現，待 L4）

## 任務看板（只列未完成或剛決定的；已完成的見 `docs/history.md`）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T1-analysis | 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 趟數；證實或推翻 F5/F6 | Opus | ⏳ 數據已有（L005） |
| T4c | twiddle_mode（roots 放 shared）、cross_mode（單一 N 表）（H12）。第 1 輪只動 `fft2/`；第 2 輪加 bench 軸 `tw=`/`cx=` | Codex | 🔨 PR #14：第 1 輪 L4 gate PASS；第 2 輪 + 測試修正（b78cf00）CI 綠、Codex review 無發現，待 L4 標籤檢查 |
| T4d | 新預設：tile_policy=1、依工作量自動選 radix（L·lanes/radix ≥ 256 → 16，否則 8）、padding 0（依 L006） | Codex | ⏸ T4c 合併後派（同樣改到 `fft2.cu` / `tile_policy.h`） |
| T4e | H15：2^24 記憶體並行度，load/store 迴圈每個 thread 一次發 K 個請求（`docs/codex-tasks/T4e-fft2-load-mlp.md`） | Codex | ⏸ T4d 合併後派（effort high） |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Opus | ⏳ |
| T7 | `fft2/tools/plan_explorer.py` | — | ⏸ 擱置（分支 `codex/t7-plan-explorer`） |
| T8 | README 作品集骨架 | — | ⏸ 有 T4 數字後再 rebase 並開 PR（分支 `codex/t8-readme`） |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 下一步（依序）

1. T4c（PR #14）：
   - 第 1 輪（1b204e6）L4 gate 全過：sm_89 和 sm_80 build 0 warning；最多 180 個暫存器、0 spill；variants 480 passed / 0 failed，128 秒。
   - 第 2 輪（c79547f，bench 軸 `tw=`/`cx=`，Codex low）已 push。待辦依序是：CI → `codex exec review --base main` → 用 `scripts/colab/gate_fft2.sh codex/t4c-fft2-twiddle` 加 2 列 sweep（`tw=1 cx=1`）檢查標籤 → 合併。
2. 依序派 T4d（`docs/codex-tasks/T4d-fft2-defaults.md`）和 T4e，前一個合併後才派下一個。
3. 三者都合併後開 A100，一次 A/B：T4c（tw/cx）、T4d 預設 vs v1、H15、index_mode 單獨一軸。依 CLAUDE.md PR 規則 7，ncu 只跑 2^20 和 2^24。

（已完成，2026-11-12：PR #8 T2c、#9、#11 T4t、#12 T4b、#13 T2d 合併；A100 A/B 用了約 8.8 單位，其中約一半是空轉，原因是腳本上傳失敗，已訂規則防止。餘額 183.72。所有 runtime 都已停止。）

## 待使用者決定

- batched 的定義（預設：N×batch 固定 2^25 個元素 = 512 MiB，另加 batch=8）。可調。
