# Codex Task T4d — fft2 auto defaults from L006

> Branch **`codex/t4d-fft2-defaults`** from `main`, **after T4c (#14) merges** (both touch `fft2.cu` and `tile_policy.h`). PR to `main`. Effort medium.

---

## Context
Read `AGENTS.md`, `CLAUDE.md`, and `docs/optimization-log.md` L006. The A100 A/B showed the following:
- `tile_policy=1` wins at 2^18–2^22. At 2^16 and 2^24 it picks the same tile as policy 0.
- Radix-16 is faster when every stage has at least `kThreads` (256) butterflies, i.e. `L·lanes/16 ≥ 256`. Otherwise radix-8 is faster, because radix-16 leaves half the threads idle and shows barrier stalls.
- `smem_padding=1` never helped and forces lanes=1 at 2^24.

## Task
1. Change the `PlanOptions::tile_policy` default to 1.
2. Add `radix_mode = -1`, meaning automatic, and make it the default. Per pass, pick 2 (radix-16) if `length·lanes/16 ≥ kThreads`, else 1 (radix-8). The rule is evaluated after tile selection. Explicit values 0/1/2 behave exactly as today. `describe()` reports the resolved mode for each pass, e.g. `radix_mode=-1(p1=2,p2=1)`.

   Pass 1 and pass 2 may resolve differently; that is the reason for choosing per pass.
3. Bench and scripts: keep the labels stable, so the bench default stays explicit.
   - With no flags, the bench keeps today's explicit v1 settings (`tp=0`, `rx=0`), so earlier results stay comparable.
   - `--fft2-radix-mode` and the variants field `rx=` also accept `-1`, labelled `,rx=auto`.
   - With `tp=1 rx=-1`, a variant is the new default.

   State in the PR whether you see a simpler approach.
4. Tests: the auto-radix rule in the CPU tile tests (a table of length, lanes, and expected radix for each pass), plus `fft2_test` coverage of the default plan at every log2 from 16 to 24.

## Constraints
- Touch only `fft2/`, `bench/`, `scripts/`, `tests/`, and `docs/measurement.md`.
- Diff ≤ 250 lines, excluding tests.
- Explicit options must be bit-identical to today.
- No performance claims.

## Gate
- CPU: `make -C fft2 test-cpu`, `pytest tests -q`, and `shellcheck scripts/*.sh`.
- GPU (Claude, L4):
  - `fft2_test --variants` exits 0;
  - a 2-row sweep at 2^20 b1 (v1 vs `tp=1 rx=-1`) where every row is ok and the labels match.
