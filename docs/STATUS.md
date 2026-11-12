# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-13（#15 T4d、#16 T4e 合併；A100 A/B 完成，L007/L008 草稿；到達 M1 檢查點）

## 任務看板（只列未完成或剛決定的；已完成的見 `docs/history.md`）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T1-analysis | 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 趟數；證實或推翻 F5/F6 | Opus | ⏳ 數據已有（L005） |
| T4f | 預設值：`io_mode=2` 改為預設（依 L008）；tw/cx 維持 0 | Codex | ⏸ 待使用者確認 L008 |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Opus | ⏳ |
| T7 | `fft2/tools/plan_explorer.py` | — | ⏸ 擱置（分支 `codex/t7-plan-explorer`） |
| T8 | README 作品集骨架 | — | ⏸ 有 T4 數字後再 rebase 並開 PR（分支 `codex/t8-readme`） |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 下一步（依序）

1. 使用者審閱 L007、L008 措辭，確認 T4f（`io_mode=2` 改為預設）。
2. **M1 檢查點**（L008）：2^20 b1 與 cuFFT 打平；2^16–2^22 為 cuFFT 的 71–99%；2^24 為 68–70%（pass 1 只到 HBM 上限 33%）。討論是否追 2^24：(a) pass 1 一次讀更多欄，或 (b) 像 VkFFT 改 3 趟。
3. README（瓶頸分析、before/after）：使用者 2026-11-13 決定先不寫。

（已完成，2026-11-13：#14 T4c、#15 T4d、#16 T4e 合併。T4e A100：gate 596 passed / 0 failed，A/B 結果在 `results/t4e_a100_20261113/`。今天 Colab 共用約 4.8 單位，餘額 178.89；所有 runtime 都已停止。fft2 編譯時間因 T4e 模板變長，sm_80 單次約 15 分鐘，CI cuda-compile 上限已調為 30 分鐘。）

## 待使用者決定

- L007、L008 結論措辭；T4f 預設值（`io_mode=2`）。
- batched 的定義（預設：N×batch 固定 2^25 個元素 = 512 MiB，另加 batch=8）。可調。
