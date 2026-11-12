# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-12（PR #8、#11 經 L4 gate 合併；T4b 已派給 Codex）

## 任務看板（只列未完成或剛決定的；已完成的見 `docs/history.md`）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| T1-analysis | 實測上限、legacy 每 kernel 達成率、cuFFT/VkFFT 趟數；證實或推翻 F5/F6 | Opus | ⏳ 數據已有（L005） |
| T4t | `tile_policy=1`（H13）：每塊 shared ≤ 32 KiB 的最大 tile、至少 2 lanes，放不下時退回 policy 0 | Codex | ✅ PR #11 合併（L4 gate 292/0；預設仍是 0，A100 A/B 後再決定） |
| T4b | register radix-8/16（H11），shared 只做一次交換（`docs/codex-tasks/T4b-fft2-register-radix.md`） | Codex | 🔨 2026-11-12 已用 `codex exec` 派出（effort high），分支 `codex/t4b-fft2-radix` |
| T2d | bench 和變體腳本加 `tp=`（tile_policy）、`rx=`（radix_mode），A100 A/B 需要（`docs/codex-tasks/T2d-bench-tile-policy-radix-axes.md`） | Codex | ⏸ T4b 合併後派（effort low） |
| T4c | twiddle 存取變體（H12），接在 T4b 之後 | Codex | ⏸ 等 T4b |
| T4.x | A100 一次 allocation A/B 所有變體 → 依 ncu 定預設值 | Opus | ⏳ |
| T5 | batched 調優、README 瓶頸分析與 before/after | Codex / Opus | ⏳ |
| T6 | `scripts/a100_session.sh` | — | ✖ 關閉（2026-11-12）：L005 已直接用 SSH 跑完 A100，不需要這層包裝。分支 `codex/t6-a100-session` 保留不合併 |
| T7 | `fft2/tools/plan_explorer.py`（不靠 GPU 預測 occupancy 等） | — | ⏸ 擱置：T4b 需要時再由 Opus 審分支 `codex/t7-plan-explorer` 決定去留 |
| T8 | README 作品集骨架 | — | ⏸ 擱置：有 T4 數字後再 rebase 並開 PR（分支 `codex/t8-readme`） |
| M1 檢查點 | 與使用者討論是否追 cuFFT | 全體 | ⏳ |

## 下一步（依序）

1. T4b 交回後：Codex 自我審查，然後 push、開 PR、跑 CI，再跑 L4 gate（`fft2_test --variants` 加上 ptxas 暫存器／spill 檢查）。
2. T2d（bench 加 tp/rx）→ L4 gate → 合併。
3. 通過後開 A100，一次跑完 A/B：
   - T4t：policy 0 vs 1，b1 和 batched；
   - T4b：radix_mode 0/1/2；
   - T2c：index_mode、smem_padding。
   依結果寫 L006，並決定各項預設值。
4. 使用者審閱 L003、L005 的措辭。
5. 接著派 T4c（twiddle）。

（已完成：PR #8 T2c、#9 T5a-fix-1、#11 T4t，皆於 2026-11-12 合併。L4 gate 用了 0.32 單位。）

## 待使用者決定

- L003、L005 結論措辭。
- batched 的定義（預設：N×batch 固定 2^25 個元素 = 512 MiB，另加 batch=8）。可調。
