# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-12（流程整理：拆出本檔、PR 規則、T6–T8 去留）

## 任務看板（只列未完成或剛決定的；已完成的見 `docs/history.md`）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T1-analysis | 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 趟數；證實或推翻 F5/F6 | Opus | ⏳ 數據已有（L005） |
| T2c | bench 加 `--fft2-index-mode`、`--fft2-smem-padding`（`docs/codex-tasks/T2c-bench-fft2-variant-axes.md`） | Codex | 🔍 PR #8 待審 |
| T5a-fix-1 | 報告產生器保留 `fft2[...]` 各變體（`docs/codex-tasks/T5a-fix-1.md`） | Codex | 🔍 PR #9 待審 |
| T4b | register radix-8/16（H11）＋ H13 附錄（shared 只做交換、`tile_policy` 佔用率導向） | Codex | 📝 待派；L005 顯示 H13 在 2^24 不成立，派出前先修附錄 |
| T4c | twiddle 存取變體（H12），接在 T4b 之後 | Codex | ⏸ 等 T4b |
| T4.x | A100 一次 allocation A/B 所有變體 → 依 ncu 定預設值 | Opus | ⏳ |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Opus | ⏳ |
| T6 | `scripts/a100_session.sh` | — | ✖ 關閉（2026-11-12）：L005 已直接用 SSH 跑完 A100，不需要這層包裝。分支 `codex/t6-a100-session` 保留不合併 |
| T7 | `fft2/tools/plan_explorer.py`（不靠 GPU 預測 occupancy 等） | — | ⏸ 擱置：T4b 需要時再由 Opus 審分支 `codex/t7-plan-explorer` 決定去留 |
| T8 | README 作品集骨架 | — | ⏸ 擱置：有 T4 數字後再 rebase 並開 PR（分支 `codex/t8-readme`） |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 下一步（依序）

1. 審 PR #8（T2c）、#9（T5a-fix-1），通過就合併。兩者互不相依，都以 main 為 base。
2. 使用者審閱 L003、L005 草稿措辭。
3. 依 L005（H13 在 2^18–2^22 成立、k=2 最佳；2^24 不成立）修改 T4b 附錄，然後派 T4b。
4. T4b 的 L4 gate 通過、合併後，才排下一次 A100（T4b + T2c 變體 A/B 一次跑完）。

## 待使用者決定

- L003、L005 結論措辭。
- batched 的定義（預設：N×batch 固定 2^25 個元素 = 512 MiB，另加 batch=8）。可調。
