# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-12（PR #14 T4c 合併；T4d 已派 Codex）

## 任務看板（只列未完成或剛決定的；已完成的見 `docs/history.md`）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T1-analysis | 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 趟數；證實或推翻 F5/F6 | Opus | ⏳ 數據已有（L005） |
| T4d | 新預設：tile_policy=1、依工作量自動選 radix（L·lanes/radix ≥ 256 → 16，否則 8）、padding 0（依 L006） | Codex | 🔨 已派（分支 `codex/t4d-fft2-defaults`，effort medium） |
| T4e | H15：2^24 記憶體並行度，load/store 迴圈每個 thread 一次發 K 個請求（`docs/codex-tasks/T4e-fft2-load-mlp.md`） | Codex | ⏸ T4d 合併後派（effort high） |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Opus | ⏳ |
| T7 | `fft2/tools/plan_explorer.py` | — | ⏸ 擱置（分支 `codex/t7-plan-explorer`） |
| T8 | README 作品集骨架 | — | ⏸ 有 T4 數字後再 rebase 並開 PR（分支 `codex/t8-readme`） |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 下一步（依序）

1. T4d：Codex 完成後 review → CI → L4。L4 腳本除了 gate，還要在 2^20 b1 跑 3 列 sweep：v1、`tp=1 rx=-1`、`tw=1 cx=1`（最後一列是補 T4c 的標籤實機檢查）。bench 必須先跑 `git submodule update --init third_party/VkFFT`。
2. T4d 合併後派 T4e（effort high）。
3. 三者都合併後開 A100，一次 A/B：T4c（tw/cx）、T4d 預設 vs v1、H15、index_mode 單獨一軸。依 CLAUDE.md PR 規則 7，ncu 只跑 2^20 和 2^24。

（已完成，2026-11-12：PR #8 T2c、#9、#11 T4t、#12 T4b、#13 T2d、#14 T4c 合併（L4 gate：480 passed / 0 failed，0 spill；L4 約 10 分鐘）；A100 A/B 用了約 8.8 單位，其中約一半是空轉，原因是腳本上傳失敗，已訂規則防止。餘額 183.72。所有 runtime 都已停止。）

## 待使用者決定

- batched 的定義（預設：N×batch 固定 2^25 個元素 = 512 MiB，另加 batch=8）。可調。
