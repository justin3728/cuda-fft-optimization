# CLAUDE.md — how to work in this repo

**Start every session by reading `docs/plan.md`** (state, task board, decisions, next step) and the latest entries of `docs/optimization-log.md`. Do not rely on chat memory; if something matters later, write it into one of those files.

## Project in one paragraph
FP64 complex-to-complex forward CUDA FFT being rebuilt from a 5-pass legacy pipeline into a **2-pass** design that approaches A100 memory-bandwidth limits (N = 2^16–2^24, batch 1 and batched). The core deliverable is being able to answer "how do you know it's fast": per-kernel Nsight Compute achievement vs **measured** HBM/L2 limits, with the remaining gap explained. Beating cuFFT in that range is a stretch goal; VkFFT is a second baseline and design reference. Milestone 1 = 2-pass + complete measurement + README bottleneck analysis with before/after — then stop and discuss with the owner.

## Roles
- **Claude (director)**: splits tasks, writes Codex prompts with acceptance criteria into `docs/codex-tasks/`, reviews Codex PRs, runs GPU jobs on Colab, analyzes data, updates `docs/plan.md` and `docs/optimization-log.md`.
- **Codex**: implements. Has no GPU; the owner pastes prompts from `docs/codex-tasks/`. Codex pushes to its own `codex/*` branches and opens PRs.
- **Owner**: pastes prompts, approves spending (GPU time), makes direction decisions. Writes in Traditional Chinese; reply in Traditional Chinese.
- Only GPU measurements count as evidence of "correct" or "faster". Label anything else as a hypothesis.
- **This is the owner's job-hunting portfolio.** Keep the owner in the loop on judgment, not on mechanics: the owner decides new task directions and approves every optimization-log conclusion (Claude drafts, owner reviews and rewords). Fix rounds and other mechanical dispatch may go to Codex directly via `codex exec` (see below).

## Writing Codex tasks (`docs/codex-tasks/*.md`)
- **Size every task to fit one Codex 5-hour usage window** (the owner is on ChatGPT Plus). Split larger work into sequential tasks.
- Every prompt must say: commit and push to the task branch after each completed item (WIP is fine), so a usage-limit stop never strands work locally.
- Every prompt defines a **gate command**: one command run on the GPU whose exit code decides pass/fail (e.g. `fft2/fft2_test`, or `results/<tag>/stage_status.csv` all OK). Gate on Colab **L4 first** (cheap, correctness/compile), then **A100** only for performance. Batch several A100 experiments into one allocation.
- Restrict each task to its own directories so parallel Codex tasks never touch the same files.
- Mechanical dispatch: `C:\Users\Justin\AppData\Local\OpenAI\Codex\bin\<hash>\codex.exe exec ...` (bundled with the Codex desktop app, logged in with the owner's account; same quota). Find the exact path with `find /c/Users/Justin/AppData/Local/OpenAI/Codex/bin -name codex.exe`.

## Hard rules
1. Legacy implementation (`fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`) stays as a selectable baseline; its numeric output must not change. New implementation lives in `fft2/`.
2. Every change → an entry in `docs/optimization-log.md`: hypothesis → ncu data (with `results/` path) → outcome. Failures too.
3. State lives only in `docs/plan.md`.
4. Official numbers only from **A100-SXM4-40GB**. Other GPUs (e.g. Colab L4) are for smoke tests; say so wherever their numbers appear.
5. Never fabricate performance numbers.

## Running GPU jobs (Colab CLI)
**Use `scripts/colab/run.sh`** for every GPU run: it allocates, clones a branch, runs one command, polls, downloads the requested path into `$TMP/colab_runs/<name>/`, and **always stops the runtime** (even on failure or Ctrl-C). Example:

```bash
scripts/colab/run.sh --gpu L4 --name t2gate --branch codex/t2-two-pass-v1 \
  --cmd 'make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test' --fetch results/xyz
```

Then copy the compact subset into `results/` and commit. The raw CLI, for anything the script does not cover:

The official `google-colab-cli` (0.7.5) is installed in the owner's **WSL Ubuntu** on their home PC (logged in with `--auth oauth2`). From Git Bash on that machine:

```bash
wsl -e bash -lc 'colab --auth oauth2 usage'                      # balance / rate
wsl -e bash -lc 'colab --auth oauth2 new -s NAME --gpu A100'     # or L4; costs compute units
wsl -e bash -lc 'colab --auth oauth2 upload -s NAME LOCAL REMOTE' # LOCAL as a WSL path: $(wslpath "C:\\...")
wsl -e bash -lc 'colab --auth oauth2 exec -s NAME -f script.py'  # runs Python on the runtime kernel
wsl -e bash -lc 'colab --auth oauth2 download -s NAME REMOTE LOCAL'
wsl -e bash -lc 'colab --auth oauth2 stop -s NAME'
```

- **Ask the owner before allocating any runtime** (A100 or L4); **always `stop` right after** the results are downloaded. L4 ≈ 1.94 units/hr.
- `colab ssh -s NAME -- CMD` is **not** supported in 0.7.5. Pattern that works: upload a bash script, start it detached from `colab exec` via `subprocess.Popen(["bash","-c","nohup /content/x.sh > /content/x.log 2>&1 &"])`, have the script touch `/content/x_done` at the end, and poll for that file (in a background loop, once a minute).
- On the runtime, `git clone` the public repo branch directly (no upload of code needed). `tar` results excluding `build/`, download, and commit only a compact subset (CSVs, `limits.json`, ncu summary `.md`/`.csv`, VkFFT manifests). Full `.ncu-rep` files and logs stay out of the repo.
- A100 allocation can fail (`Bad Gateway`, timeouts); retry once, then ask whether to fall back to L4.
- Colab environment (Nov 2026): CUDA 13.0, driver 580.x, ncu 2025.3.1 preinstalled with counter access, root, Python 3.13. CUDA 13 cannot build `sm_61` (legacy Makefile default) → always pass `CUDA_ARCH=sm_80` (`sm_89` on L4).
- Notebook fallback (owner presses Run all): `notebooks/colab_preflight.ipynb`. Never drive Colab through a browser.

## Measurement tooling (PR #1, `codex/t1-measurement-tooling`)
`scripts/run_t1_all.sh --tag TAG [--quick] [--skip-ncu] [--dry-run]` builds and runs: env capture, bandwidth limits (`bandwidth/limits.json`, per-size `pass_floor.csv`), sweep (legacy/cuFFT/VkFFT, hot & cold timing, correctness vs cuFFT), VkFFT kernel export, ncu (NVTX-filtered), analysis. Details: `docs/measurement.md`.

## Measurement rules learned so far
- When the working set fits in L2 (40 MB on A100; e.g. N = 2^20 is 16 MiB data + workspace), a kernel's writes stay in L2 and are written back after it ends: per-kernel DRAM bytes undercount traffic and "% of HBM" can exceed 100%. **Judge such configs by L2 metrics**; DRAM metrics only when working set ≫ L2.
- Calibrate DRAM byte counts with the bwtest copy kernel on the same GPU before converting bytes into "number of memory passes" (L4 showed a 1.15× DRAM factor).
- ncu defaults lock clocks to base and flush caches; the scripts use `--clock-control none` and record the cache policy. State the settings next to any ncu number.

## Git
- Work on branches; the owner has allowed Claude to push docs/results updates to `main` in this workflow. Codex PRs are reviewed before merge; never push to a `codex/*` branch.
- Commit messages end with the co-author line from the session's attribution instructions.
