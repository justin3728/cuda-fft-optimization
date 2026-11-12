# 階段進度摘要（2026-11-13）

給外部審查者。本文件只引用 repo 內已 commit 的實測結果；沒有量到的地方標「**缺**」，推論標「**推論**」。詳細條目在 `docs/optimization-log.md`（L000–L008），原始數據在 `results/`。

> L007、L008 兩個條目的結論措辭是草稿，專案擁有者尚未審閱。

---

## 1. 目標與範圍

- **題目**：FP64 complex-to-complex 正向 FFT，N = 2^16–2^24，batch 1 與 batched。
- **做法**：把既有 5 趟（5 個 kernel）的 legacy 實作，改寫成 2 趟的新實作 `fft2/`（N = N1 × N2，pass 1 做欄、pass 2 做列）。
- **核心交付**：能回答「怎麼知道它快」，也就是每個 kernel 對照**實測**的 HBM／L2 上限，說明剩餘差距的原因。
- **比較對象**：cuFFT（主要基準）、VkFFT（第二基準與設計參考）、legacy（改寫前）。
- **正式平台**：A100-SXM4-40GB（Colab）、CUDA 13.0、sm_80。L4、G4 只用於正確性與工具冒煙測試，數字不作效能結論。
- **里程碑 M1 的定義**（`docs/plan.md` §1）：
  1. 2-pass 實作涵蓋全部尺寸，並通過正確性驗證；
  2. 量測完整：頻寬上限、三方 sweep、每個 kernel 的 ncu 達成率；
  3. README 有瓶頸分析和 before/after；
  4. 停下來討論是否繼續追 cuFFT。

## 2. 結論先講

| 項目 | 狀態 |
|---|---|
| 2-pass 結構 | ✅ 每次執行恰好 2 個 kernel；DRAM 流量在 2^24 為理想值（每 pass 讀 270 MB／理想 268 MB） |
| 正確性 | ✅ 全部量測列對 cuFFT 的 rel L2 ≤ 6.1e-16（門檻 1e-12）；`fft2_test --variants` 596 passed / 0 failed |
| 與 cuFFT 比（最新設定） | 2^20 b1 打平（99%）；2^16–2^22 為 71–99%；2^24 為 68–70% |
| 相對改寫前的 fft2 v1 | 1.23–2.69 倍 |
| 相對 legacy（≤ 2^20 才有） | 1.82–11.6 倍 |
| 贏過 cuFFT 的格子 | 14 格中 0 格（最接近的是 2^16 b512 與 2^20 b1，皆為 99%） |
| 贏過 VkFFT 的格子 | 14 格中 1 格（2^18 b8，102%） |
| M1 第 3 項（README 瓶頸分析、before/after） | **缺**（擁有者決定這階段先不寫） |

## 3. 量測方法

- **計時**：`bench/fft_bench`。「hot」是 15 次 trial 的中位數，每次 trial 連續執行 20 次；另有 cold（清 L2、單次執行），本文只引用 hot。正確性在同一個程序內對 cuFFT 比對，固定 seed 12345。
- **實測上限**（A100，`results/t1_a100_20261112/bandwidth/limits.json`）：

  | 項目 | GB/s |
  |---|---|
  | HBM read | 1455 |
  | HBM write | 1500 |
  | HBM copy（本文 % 的分母） | 1363（規格值 1555 的 87.6%） |
  | L2 read plateau | 2741 |
  | L2 copy plateau | 2858 |

  DRAM copy 的校正係數是 0.997。
- **ncu**：`--clock-control none`、`--cache-control all`，NVTX 過濾，只抓實作本身的 kernel。
- **方法學上的已知限制**：
  - working set 放得進 L2（40 MiB）的設定，例如 2^20，kernel 寫入的資料會留在 L2，事後才寫回。每個 kernel 的 DRAM bytes 因此會低估，「% of HBM」可能超過 100%，這類設定應改用 L2 指標判斷（L001）。
  - ncu 只在 2^20 和 2^24 收集，這是成本控制規則（CLAUDE.md PR 規則 7）。
- **跨配置比較**：基準與 fft2 v1 的數字來自 2026-11-12 的 A100 配置（`results/ab_a100_20261112/`）。最新 fft2 的數字來自 2026-11-13 的另一次配置（`results/t4e_a100_20261113/`）。11-13 當次重新量了 cuFFT 2^20 b1（92.4 vs 92.5 µs）和 2^24 b1（1259.3 vs 1261.3 µs），差距 < 0.2%；VkFFT 和 legacy 當次沒有重新量。

## 4. 最終效能（A100，hot 中位數 µs）

「最新」= T4d 預設（`tile_policy=1`、radix 自動選擇）加上 `io_mode=2`，不開 `twiddle_mode`、`cross_mode`。注意 `io_mode=2` 目前還**不是**程式的預設值（見 §8）。

| N | batch | cuFFT | VkFFT | legacy | fft2 v1 | **fft2 最新** | 最新為 cuFFT 的 | 最新為 VkFFT 的 | v1 → 最新 |
|---|---|---|---|---|---|---|---|---|---|
| 2^16 | 1 | 14.0 | 17.4 | 36.4 | 32.8 | 19.6 | 71% | 89% | 1.68× |
| 2^16 | 8 | 25.4 | 29.8 | 292.4 | 44.2 | 32.8 | 78% | 91% | 1.35× |
| 2^16 | 512 | 1596.6 | 1601.6 | 18760.2 | 1983.1 | 1611.2 | 99% | 99% | 1.23× |
| 2^18 | 1 | 23.7 | 23.8 | 66.3 | 62.4 | 29.2 | 81% | 81% | 2.13× |
| 2^18 | 8 | 126.3 | 141.2 | 540.8 | 247.1 | 138.4 | 91% | 102% | 1.79× |
| 2^18 | 128 | 1615.3 | 1726.3 | 8643.6 | 3068.4 | 1760.5 | 92% | 98% | 1.74× |
| 2^20 | 1 | 92.5 | 81.6 | 170.4 | 251.9 | 93.5 | 99% | 87% | 2.69× |
| 2^20 | 8 | 513.2 | 487.3 | 1440.2 | 1398.8 | 614.7 | 83% | 79% | 2.28× |
| 2^20 | 32 | 1833.4 | 1801.9 | 5741.4 | 5318.7 | 2320.0 | 79% | 78% | 2.29× |
| 2^22 | 1 | 320.7 | 301.6 | 不支援 | 767.0 | 374.2 | 86% | 81% | 2.05× |
| 2^22 | 8 | 2032.4 | 2014.5 | 不支援 | 5787.2 | 2545.5 | 80% | 79% | 2.27× |
| 2^24 | 1 | 1261.3 | 1289.8 | 不支援 | 3213.1 | 1844.6 | 68% | 70% | 1.74× |
| 2^24 | 2 | 2496.5 | 2528.2 | 不支援 | 6420.1 | 3622.3 | 69% | 70% | 1.77× |
| 2^24 | 8 | 9913.7 | 10012.3 | 不支援 | 25654.3 | 14225.0 | 70% | 70% | 1.80× |

- 「為 cuFFT 的 X%」= cuFFT 時間 ÷ fft2 時間，100% 代表一樣快，越大越好。
- 大 batch 欄是「N × batch = 2^25 個元素（512 MiB）」的設定。2^22 時這個設定剛好也是 batch 8，所以表中只列一列。
- 最新設定在同一次配置內，15 次 trial 的 p10–p90 最多偏離中位數 1.13%。開 `tw=1 cx=1` 的那三列最多偏離約 10%。L006 另外在 2^16 b1 觀察到約 ±10% 的差異：兩個 tile 相同的變體量出不同時間。
- **缺**：奇數 log2（2^17、19、21、23）在最新設定下沒有計時。v1 與基準在 2^16–2^24 的每個 log2 都有（`results/t1_a100_20261112/`）；最新設定的正確性也在每個 log2 都驗證過。
- **缺**：跨配置的重複性。每個設定只在一次配置裡量過。

## 5. 每個 kernel 的瓶頸（ncu，最新設定）

**2^24 b1**（working set ≫ L2，用 HBM 判斷；每個 pass 理想是讀 268 MB、寫 268 MB，以 copy 上限換算 394 µs）：

| kernel | 時間 µs | DRAM 讀 MB | DRAM 寫 MB | 暫存器 | 理論佔用率 | % of HBM copy 上限 | 主要 stall（pc sampling） |
|---|---|---|---|---|---|---|---|
| pass 1（欄） | 1190.7 | 270.3 | 256.3 | 164 | 1 block/SM（128 KiB shared） | 33% | long_scoreboard 44%、lg_throttle 16% |
| pass 2（列） | 645.2 | 268.7 | 254.0 | 168 | 1 block/SM（128 KiB shared） | 61% | long_scoreboard 25%、lg_throttle 27% |

（stall 百分比 = 該原因的 pc sample ÷ 總 sample，數字取自 `results/t4e_a100_20261113/ab_r3/ncu/*N16777216_b1_b1_cache_all.csv`。）

- **解讀（推論）**：兩個 pass 的流量都已經是理想值，所以差距不是多搬了資料，而是存取效率。pass 1 每列只讀 2 欄（32 B），一個 warp 的一次 load 要碰 16 條 cache line。
- **對照**：L005 量過 cuFFT 在 2^24 用 3 個 kernel，每個 kernel 達到 mixed HBM 上限的 82–91%。

**2^20 b1**（L2-resident）：pass 1 57.2 µs、pass 2 44.9 µs，各 64 個暫存器，32 KiB shared。

- **缺**：L2 達成率（% of L2 上限）還沒算。依 §3 的方法學限制，這個尺寸不能用 DRAM 指標判斷。

**缺**：最新設定在 2^16、2^18、2^22 的 ncu；VkFFT／cuFFT 在 11-13 配置的 ncu（引用 L005）。

## 6. 做過的優化：有效的

| 假設 | 改動 | 實測結果 | 條目 |
|---|---|---|---|
| 2-pass 結構 | `fft2/` v1：2 個 kernel，shared memory 做 block FFT | A100 上 DRAM 每 kernel 讀 1.00 趟、寫 0.94–0.98 趟。但 v1 只達到上限的 19–31%，是 cuFFT 時間的 1.2–2.9 倍 | L003、L005 |
| H13 佔用率太低 | `tile_policy=1`：tile 以 32 KiB 為目標，至少 2 欄 | 2^20 b32 快 1.87 倍（auto C=8，12.5% 佔用率 → C=2，50%）；2^22 b8 快 1.41 倍 | L005、L006 |
| H11 shared 上的 radix-4 迴圈 | register radix-8／16（`radix_mode`） | radix-16 讓 2^24 b1 從 3213 降到 2568 µs（快 1.25 倍）；2^20 則是 radix-8 較快（107.6 vs 126.8 µs） | L006 |
| radix 依工作量選擇 | T4d：每個 pass 依 L·lanes/16 ≥ 256 選 radix-16，否則 radix-8 | 規則由 L006 推導；作為預設值的獨立計時是**缺**，最新設定已包含它 | L006、L008 |
| H15 記憶體並行度不足 | `io_mode=2`：照 VkFFT 產生的 kernel 結構，global 直接載進 register 就做第一段 radix，最後一段直接從 register 寫回 global | 2^24 b1 快 1.39 倍（2568 → 1845 µs），2^22 b1 快 1.22 倍，2^20 b1 快 1.15 倍（與 cuFFT 打平） | L007、L008 |

## 7. 做過但沒效（或有害）的嘗試

| 假設 | 改動 | 實測結果 | 條目 |
|---|---|---|---|
| H13 在 2^24 | 縮小 tile 提高佔用率（k=1） | 佔用率從 12.5% 升到 25%，時間幾乎不變（3243 vs 3203 µs），每個 kernel 仍只達上限的 22–28%。k=1 另外讓 DRAM 讀取變成理想值的 1.06–1.26 倍，2^16–2^18 batched 明顯變慢 | L005 |
| H10 shared bank conflict | `smem_padding=1` | store bank conflict 沒有下降（0.926M vs 0.931M）。2^24 時 tile 被迫降到 1 欄，反而變慢（3213 → 3749 µs） | L006 |
| H9 64-bit 索引除法 | `index_mode=1`（u32 shift/mask） | 只和 padding 一起量過，無法分辨各自的效果；**單獨的 A/B 缺** | L006 |
| radix-16 在中等工作量 | L=1024、2 欄時用 radix-16 | 256 個 thread 中有一半閒置，barrier stall 16–24%，2^20 b1 比 radix-8 慢（126.8 vs 107.6 µs）。因此改成依工作量選擇 | L006 |
| H12 twiddle 放 shared | `twiddle_mode=1` | 2^24 時 pass 2 的 shared 讀取 bank conflict 從 0.03M 增加到 16.0M，pass 2 從 645 升到 1258 µs | L008 |
| H12 單一 cross twiddle 表 | `cross_mode=1`（長度 N 的表） | 2^24 的表有 256 MiB，遠大於 L2；pass 1 從 DRAM 讀了 1196 MB（理想 268 MB 的 4.5 倍），2^24 b1 整體 3755 vs 1845 µs。2^20 時也多讀了 1.7 倍 | L008 |
| tw 與 cx 的個別效果 | — | 兩者只一起開過，個別的 A/B **缺** | L008 |
| H15 只把 load 分批 | `io_mode=1`：每個 thread 先發出所有 load，再寫進 shared | 幾乎每格都比 `io_mode=2` 慢，部分尺寸比 `io_mode=0` 還慢（例如 2^18 b128：2886 vs 2487 µs，兩者都開 tw/cx） | L008 |
| 新預設在 2^16 b1 | 最新設定 | 19.6 µs，比 L006 在這一格最快的變體（14.9 µs，`im=1 pad=1 tp=1 rx=2`）還慢；但這一格雜訊約 ±10%（見 §4） | L006、L008 |

## 8. 尚未完成／缺的項目

- **M1 第 3 項**：README 的瓶頸分析和 before/after 還沒寫。
- **預設值**：`io_mode=2` 還不是 `PlanOptions` 的預設值（T4f 待辦），目前要明確指定才會用到。`twiddle_mode`、`cross_mode` 預設是 0。
- **量測**：
  - 奇數 log2 在最新設定下的計時；
  - 跨配置的重複性；
  - 2^20 的 L2 達成率；
  - 2^16／2^18／2^22 的 ncu；
  - `index_mode` 單獨的 A/B；
  - tw 與 cx 分開的 A/B。
- **2^24 的方向（推論，未驗證）**：pass 1 每列只讀 2 欄是剩下的主要瓶頸，有兩條路：
  - (a) 重新設計 pass 1，讓它一次讀更多欄；
  - (b) 像 VkFFT 在 FP64、N > 2^22 時一樣，改成 3 趟（`swapTo3Stage4Step`，L007）。
  
  兩者都還沒做。
- **工程面**：T4e 之後 fft2 的模板實例變多，sm_80 單次編譯約 15 分鐘（A100 實測）。CI 的 cuda-compile 上限已從 15 分鐘調到 30 分鐘。

## 9. 過程中的問題（影響成本，不影響數據）

- 2026-11-12：A100 空轉約 67 分鐘。上傳的腳本是 0 bytes，輪詢又只檢查完成檔案。之後在 CLAUDE.md 訂了「先驗證檔案大小、監控存活」的規則。
- 2026-11-13：T4e 第一次上 A100 時，因為 `-Werror` 抓到未使用的成員而編譯失敗，約 2 分鐘後停止。修正後重新配置才跑出結果。
- 兩次 L4 gate 的標籤 sweep 都因為我的腳本錯誤沒有跑完，一次是缺 VkFFT submodule，一次是 tag 重複。新標籤（`rx=auto`、`io=`）在 A100 run 的輸出中有正確出現。

## 10. 重現方式與資料位置

| 內容 | 位置 |
|---|---|
| 計畫、決策紀錄 | `docs/plan.md` |
| 每次實驗的假設、數據、結論 | `docs/optimization-log.md`（L000–L008） |
| 實測上限與基準全尺寸 sweep（v1、cuFFT、VkFFT、legacy） | `results/t1_a100_20261112/` |
| tile／radix／index／padding A/B | `results/ab_a100_20261112/` |
| twiddle／cross／io A/B（最新設定 = r3） | `results/t4e_a100_20261113/`（含 `summary.md`） |
| 量測工具說明 | `docs/measurement.md` |
| 實作 | `fft2/`（`fft2.cu`、`detail/tile_policy.h`）、基準程式 `bench/` |

重現最新設定的 sweep（A100）：

```bash
make -B tools bench TAG=x CUDA_ARCH=sm_80
scripts/run_sweep.sh --tag x --impls fft2 --log2 16,18,20,22,24 --batch-modes b1,b8,t25 --trials 15 \
  --fft2-tile-policy 1 --fft2-radix-mode -1 --fft2-io-mode 2
```

相關 PR：#1、#2、#3（工具、v1、CI）、#8、#9、#13（bench 變體軸）、#11（tile_policy）、#12（register radix）、#14（twiddle/cross）、#15（預設值）、#16（register I/O）。
