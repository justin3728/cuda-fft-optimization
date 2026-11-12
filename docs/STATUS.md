# 目前狀態（每個 session 先讀這份）

> 只放「現在」：看板、下一步、待決事項。目標、架構、決策紀錄在 `docs/plan.md`；過去的流水帳在 `docs/history.md`。
> 最後更新：2026-11-13（方向決定：優化凍結，進入作品集收尾）

## 方向決定（擁有者，2026-11-13）

- 優化到此凍結：不追 2^24，不再開新的效能假設。M1 檢查點就此結案。
- 只做收尾：把 repo 整理成求職作品集，然後打 tag 凍結。
- README 的主軸是 fft2 對 cuFFT、VkFFT 和實測硬體上限的比較，legacy 只當歷史。用英文寫；optimization log 維持中文。
- 實驗快照存成 tag `experiments-20261113`（= main `ded5fc9`），L005–L008 都能從這個 tag 重現。之後的 main 只保留勝出的路徑。
- 流程文件（CLAUDE.md、AGENTS.md、`docs/codex-tasks/`、STATUS、plan、history、stage-summary）在打 tag 前從 main 刪除，git 歷史和實驗 tag 裡仍然保留。
- 打 tag 之後刪除遠端所有 `codex/*`、`docs/*` 分支（T7、T8 放棄；T8 的內容可以參考）。

## 收尾任務（依序；PR 規則照舊，一次一個 Codex PR）

| ID | 任務 | 負責 | 狀態 |
|---|---|---|---|
| F1 | 精簡 fft2：只留 `tile_policy=1`、radix 自動選擇、`io_mode=2`，並刪掉其他變體（`io_mode` 0/1、`twiddle_mode`、`cross_mode`、`smem_padding`、`index_mode`、舊 tile policy、固定 radix），bench 和 scripts 上對應的變體軸一起刪。驗收：L4 gate 通過，sm_80 編譯時間大幅下降 | Codex | ⏳ 待寫 spec |
| F2 | 目錄整理：legacy 搬到 `legacy/`（`fft_cuda.*`、`benchmark.cpp`、`profile_stages.cu`、舊 Makefile、舊 results 的 png/csv）。根目錄 Makefile 改成建 fft2、bench、tools。早期的 smoke/preflight/gate 結果移到 `results/archive/`。同步更新 CI 和 scripts | Codex | ⏸ F1 合併後派 |
| F3 | 最終 A100 run（一次 allocation，跑之前先問擁有者）：在凍結的 main 上跑 `run_t1_all.sh` full，含頻寬上限，以及 legacy、cuFFT、VkFFT、fft2 預設的 sweep（log2 16–24 全部、b1/b8/t25、15 trials）。ncu 跑四方的 2^20（含 L2 指標）和 2^24。另外重跑一次 sweep 看同一次配置內的重複性 | Claude | ⏸ F1、F2 合併後 |
| F4 | 圖表：b1 時間對 N 的曲線（四方）、各格為 cuFFT／VkFFT 的百分比、每個 kernel 達成率對實測 HBM／L2 上限（2^20、2^24）。由腳本從 results 產生；可以先用 `results/t1_a100_20261112/` 開發 | Codex | ⏸ 可與 F2 並行（不同目錄） |
| F5 | README（英文）：headline、方法、結果、每個 kernel 的瓶頸分析、沒效的嘗試（連到 log）、legacy 歷史、重現步驟 | Claude 起草，擁有者審 | ⏸ F3、F4 之後 |
| F6 | 刪除流程文件 → 打 tag `v1.0` → 刪除舊分支 | Claude | ⏸ 最後 |

- before/after：同一次配置內比 legacy 對 fft2 最終版。fft2 v1 的中間數字引用 11-12 那次配置，並標明是跨配置的數字。
- 不再補的量測（屬於已凍結的方向）：`index_mode` 單獨的 A/B、tw/cx 分開的 A/B、2^24 的改進。README 裡如實寫成「未做」。

## 待使用者決定

- L007、L008 的結論措辭（F5 之前要審完）。
- batched 的定義維持現狀：N×batch = 2^25（512 MiB）加上 batch=8。
- F3 A100 開機時間（F1、F2 合併後再約）。
