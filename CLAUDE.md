# CLAUDE.md — how to work in this repo

**Start every session by reading `docs/STATUS.md`** (task board, next steps, open decisions; kept under ~60 lines). Open `docs/plan.md` (goals, architecture, decisions) and `docs/optimization-log.md` only for the sections the task needs. Do not rely on chat memory; if something matters later, write it into one of those files.

## Project in one paragraph
FP64 complex-to-complex forward CUDA FFT being rebuilt from a 5-pass legacy pipeline into a **2-pass** design that approaches A100 memory-bandwidth limits (N = 2^16–2^24, batch 1 and batched). The core deliverable is being able to answer "how do you know it's fast": per-kernel Nsight Compute achievement vs **measured** HBM/L2 limits, with the remaining gap explained. Beating cuFFT in that range is a stretch goal; VkFFT is a second baseline and design reference. Milestone 1 = 2-pass + complete measurement + README bottleneck analysis with before/after — then stop and discuss with the owner.

## Roles
Planning was delegated to Claude on 2026-11-12 (`docs/plan.md` §8).

| Who | Does |
|---|---|
| **Owner** | Approves GPU spending and handles Colab account switching; makes direction decisions; approves every optimization-log conclusion (Claude drafts, owner rewords); M1 checkpoint. Pastes prompts into Codex. Writes in Traditional Chinese; reply in Traditional Chinese. |
| **Claude Opus** (director) | Picks the next hypothesis, writes task specs into `docs/codex-tasks/`, reviews kernel and measurement-method diffs, runs GPU jobs via the Colab CLI (after asking), interprets data, drafts log entries. |
| **Claude Sonnet** (subagent) | Mechanical work Opus delegates: merge and push reviewed PRs, run CPU checks (pytest, shellcheck) and report pass/fail, condense a results directory into a short digest, update the `docs/STATUS.md` board, formatting and line-ending fixes, first-pass review of CI/script/docs-only PRs. |
| **Codex** | Implements. Has no GPU. Pushes to its own `codex/*` branches and opens PRs. |

- Waiting for a GPU job to finish needs no model: use a background wait or monitor, not a polling agent.
- Only GPU measurements count as evidence of "correct" or "faster". Label anything else as a hypothesis.
- **This is the owner's job-hunting portfolio.** Keep the owner in the loop on judgment, not on mechanics. Fix rounds and other mechanical dispatch may go to Codex directly via `codex exec` once that path has been tried and confirmed.

## PR rules
1. Every Codex branch starts from `main`, and every PR targets `main`. No stacked PRs; if a task depends on another, dispatch it after the first one merges.
2. Merge only when CI is green and, for any PR touching `fft2/` or `bench/`, the L4 gate exits 0. Run the gate **before** merging, not after.
3. Merge through GitHub (button or API) so the PR shows as merged. Write the review verdict as a PR comment, not only in the merge commit.
4. Keep each PR under ~600 changed lines (excluding `results/`); split larger tasks.
5. At most 2 Codex PRs open at once. Every task traces to a recorded hypothesis or a confirmed gap. To use Codex quota that would otherwise expire, pick small tasks from that list rather than speculative tooling.
6. Book an A100 only when a batch of A/B comparisons is ready to run together.

## Coding principles (Codex and Claude)
Adapted from the Karpathy-inspired guidelines. They apply to every change in this repo.

1. **Think before coding.** If the task spec is ambiguous, write your assumptions in the PR description. Do not silently pick one interpretation. If a simpler approach exists than the spec suggests, say so in the PR.
2. **Simplicity first.** Write the minimum code that meets the spec: no options, flags, abstractions, or error handling that the spec did not ask for. If the diff grows past the spec's size cap, stop and split it.
3. **Surgical changes.** Touch only the paths the spec allows. Do not reformat, rename, or "improve" adjacent code. Never change protected legacy files. Remove only what your own change made unused; mention other dead code in the PR instead of deleting it.
4. **Goal-driven.** "Done" means the spec's gate commands exit 0. Write or extend the test or gate first, then make it pass. Report results exactly as run; never claim performance without GPU data.

## Writing Codex tasks (`docs/codex-tasks/*.md`)
- **Size every task to fit one Codex 5-hour usage window** (the owner is on ChatGPT Plus). Split larger work into sequential tasks.
- Every prompt must say: commit and push to the task branch after each completed item (WIP is fine), so a usage-limit stop never strands work locally.
- Every prompt defines a **gate command**: one command run on the GPU whose exit code decides pass/fail (e.g. `fft2/fft2_test`, or `results/<tag>/stage_status.csv` all OK). Gate on Colab **L4 first** (cheap, correctness/compile), then **A100** only for performance. Batch several A100 experiments into one allocation.
- Restrict each task to its own directories so parallel Codex tasks never touch the same files.
- Keep a task spec to about one page: goal and hypothesis ID, allowed and forbidden paths, at most 4 deliverables, CPU gate command, GPU gate command with expected output files, a diff-size cap, and "no performance claims". `T2c-bench-fft2-variant-axes.md` is the model to follow.
- **Direct dispatch (since 2026-11-12):** Claude runs `codex exec` (the CLI bundled with the Codex desktop app; same quota; local path in the operator's private notes) in a clean clone, with sandbox `workspace-write` and approval `never`. Codex implements on its `codex/*` branch with no network access. The Windows sandbox cannot write `.git`, and `--add-dir` does not help. Codex leaves its changes in the working tree, and Claude commits them on its behalf with author `Codex`. Claude pushes, opens the PR, and reviews it. The owner no longer pastes prompts.
- **Review order (to spend Codex quota, not Claude's):**
  1. Codex implements.
  2. Claude runs `codex exec review` on the branch (effort medium) and feeds its findings back to Codex as a fix round.
  3. CI runs.
  4. Claude reads only Codex's review summary, the PR description, the gate results, and the diff stat. Claude opens the full diff only for kernel or measurement-method changes, or when something looks off.
  5. GPU gate, then merge.
- **Reasoning effort per task:** pass `-c model_reasoning_effort="..."` on each dispatch. This overrides the owner's config for that run only.

  | Task type | Effort | Examples |
  |---|---|---|
  | Mechanical, fully specified | low | docs updates, flag changes, small fix rounds |
  | Normal implementation, ≤ 300 lines | medium | tile_policy, script changes, extra tests |
  | Hard kernel or algorithm work | high | register radix (T4b), twiddle variants (T4c) |
  | Correctness-critical deep debugging | xhigh / max | rare, e.g. a gate still failing after a high run |

## Hard rules
1. Legacy implementation (`fft_cuda.cu`, `fft_cuda.h`, `benchmark.cpp`, `profile_stages.cu`) stays as a selectable baseline; its numeric output must not change. New implementation lives in `fft2/`.
2. Every change → an entry in `docs/optimization-log.md`: hypothesis → ncu data (with `results/` path) → outcome. Failures too.
3. Current state lives only in `docs/STATUS.md`; goals, architecture, and decisions in `docs/plan.md`.
4. Official numbers only from **A100-SXM4-40GB**. Other GPUs (e.g. Colab L4) are for smoke tests; say so wherever their numbers appear.
5. Never fabricate performance numbers.

## Running GPU jobs (Colab CLI)
**Preferred: SSH** (used for L004 and L005; see below). `scripts/colab/run.sh` is the older `colab exec`-based wrapper: it allocates, clones a branch, runs one command, polls, downloads into `$TMP/colab_runs/<name>/`, and always stops the runtime. It has not been updated for SSH yet. Example:

```bash
scripts/colab/run.sh --gpu L4 --name t2gate --branch codex/t2-two-pass-v1 \
  --cmd 'make -C fft2 CUDA_ARCH=sm_89 && fft2/fft2_test' --fetch results/xyz
```

Then copy the compact subset into `results/` and commit. The raw CLI, for anything the script does not cover:

The official `google-colab-cli` (0.7.5) is installed on the operator's machine (logged in with `--auth oauth2`). Typical commands:

```bash
wsl -e bash -lc 'colab --auth oauth2 usage'                      # balance / rate
wsl -e bash -lc 'colab --auth oauth2 new -s NAME --gpu A100'     # or L4; costs compute units
wsl -e bash -lc 'colab --auth oauth2 upload -s NAME LOCAL REMOTE' # LOCAL as a WSL path: $(wslpath "C:\\...")
wsl -e bash -lc 'colab --auth oauth2 exec -s NAME -f script.py'  # runs Python on the runtime kernel
wsl -e bash -lc 'colab --auth oauth2 download -s NAME REMOTE LOCAL'
wsl -e bash -lc 'colab --auth oauth2 stop -s NAME'
```

- **Ask the owner before allocating any runtime** (A100 or L4); **always `stop` right after** the results are downloaded. L4 ≈ 1.94 units/hr.
- **No idle GPU time, ever.** A billed runtime that sits idle is wasted money. On 2026-11-12, an A100 sat idle for about 67 minutes because the uploaded script was 0 bytes and only a done-file was polled. Mandatory checklist:
  1. **Prepare before allocating.** Have the script ready and the branch pushed before `new`. Allocate only when you can start the job immediately.
  2. **Send scripts over ssh stdin** (`ssh colab-NAME 'cat > /content/x.sh' < x.sh`), then check the remote byte count (`wc -c`) against the local file.
  3. **Verify that the job actually started.** About 30 s after launch, the log must show progress (GPU name, commit hash). If the log is empty or the process is missing, fix it or `stop` right away.
  4. **Poll for liveness, not only completion.** Each poll checks for the done-file **and** for log growth or the job's process. If neither has changed for about 10 minutes, investigate. If the job is dead, `stop` the runtime immediately. When you check the process with `pgrep -f` over ssh, bracket the first letter of the pattern (`"[r]un_fft2_variants"`); otherwise the ssh command line matches itself and the job always looks alive.
  5. **Stop as soon as the job ends:** download, `stop`, then analyze offline. Never leave a runtime up while you write analysis or wait on Codex.
  6. **Error path:** if anything fails (allocation, clone, build), `stop` first, then debug locally.
- **SSH works (verified 2026-11-12; used for the L005 A100 run)** through `colab ssh --proxy-mode` as an OpenSSH ProxyCommand. A local `~/.ssh/config` entry maps `colab-NAME` to session `NAME`, user root.
  - Flow: `colab --auth oauth2 new -s NAME --gpu A100`, then `ssh -o BatchMode=yes colab-NAME 'CMD'`, then `colab --auth oauth2 stop -s NAME`.
  - The remote exit code comes back through ssh, and `git clone` of the public repo works on the runtime.
  - Prefer this for gate commands. For long jobs use `nohup` plus a done-file, and poll over ssh.
- Old `colab exec` pattern (still valid fallback; note `colab ssh -s NAME -- CMD` itself is not supported in 0.7.5): upload a bash script, start it detached from `colab exec` via `subprocess.Popen(["bash","-c","nohup /content/x.sh > /content/x.log 2>&1 &"])`, have the script touch `/content/x_done` at the end, and poll for that file (in a background loop, once a minute).
- On the runtime, `git clone` the public repo branch directly (no upload of code needed). `tar` results excluding `build/`, download, and commit only a compact subset (CSVs, `limits.json`, ncu summary `.md`/`.csv`, VkFFT manifests). Full `.ncu-rep` files and logs stay out of the repo.
- A100 allocation can fail (`Bad Gateway`, timeouts); retry once, then ask whether to fall back to L4.
- **Do not request High-RAM** (`--high-mem` in the CLI, "大量 RAM" in the UI). The owner observed that A100 is much easier to get with it off. The CLI default is off. The jobs here do not need it.
- **Accounts:** A100 availability differs between Google accounts. Switching accounts is the owner's call; the mechanics are in the operator's private notes.
- Colab environment (Nov 2026): CUDA 13.0, driver 580.x, ncu 2025.3.1 preinstalled with counter access, root, Python 3.13. CUDA 13 cannot build `sm_61` (legacy Makefile default) → always pass `CUDA_ARCH=sm_80` (`sm_89` on L4).
- Notebook fallback (owner presses Run all): `notebooks/colab_preflight.ipynb`. Never drive Colab through a browser.

## Measurement tooling
`scripts/run_t1_all.sh --tag TAG [--quick] [--skip-ncu] [--dry-run]` builds and runs: env capture, bandwidth limits (`bandwidth/limits.json`, per-size `pass_floor.csv`), sweep (legacy/cuFFT/VkFFT, hot & cold timing, correctness vs cuFFT), VkFFT kernel export, ncu (NVTX-filtered), analysis. Details: `docs/measurement.md`.

## Measurement rules learned so far
- When the working set fits in L2 (40 MB on A100; e.g. N = 2^20 is 16 MiB data + workspace), a kernel's writes stay in L2 and are written back after it ends: per-kernel DRAM bytes undercount traffic and "% of HBM" can exceed 100%. **Judge such configs by L2 metrics**; DRAM metrics only when working set ≫ L2.
- Calibrate DRAM byte counts with the bwtest copy kernel on the same GPU before converting bytes into "number of memory passes" (L4 showed a 1.15× DRAM factor).
- ncu defaults lock clocks to base and flush caches; the scripts use `--clock-control none` and record the cache policy. State the settings next to any ncu number.

## Git
- Work on branches; the owner has allowed Claude to push docs/results updates to `main` in this workflow. Codex PRs follow the PR rules above; never push to a `codex/*` branch.
- Commit messages end with the co-author line from the session's attribution instructions.
