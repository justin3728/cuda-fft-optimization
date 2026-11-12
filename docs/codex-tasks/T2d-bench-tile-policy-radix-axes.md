# Codex Task T2d — expose `tile_policy` and `radix_mode` in the bench and variants runner

> Dispatch **after T4b is merged** (`radix_mode` must exist in `fft2::PlanOptions`). Branch **`codex/t2d-variant-axes`** from `main`; PR to `main`. Small task, effort low.

---

## Context
Read `AGENTS.md` and `CLAUDE.md`. T2c (PR #8) added `--fft2-index-mode` and `--fft2-smem-padding`; copy that change's pattern exactly. `main` now also has `PlanOptions::tile_policy` ∈ {0,1} (T4t) and `radix_mode` ∈ {0,1,2} (T4b). The next A100 run must A/B these two axes, but the bench cannot select them yet.

## Task
1. `fft_bench`: add `--fft2-tile-policy P` and `--fft2-radix-mode M`, both defaulting to 0. They go into `PlanOptions`, and the sweep driver forwards them to the workers.
2. Label: append `,tp=P` and `,rx=M` to `fft2_name()` **only when nonzero**, in this order: after `pad`, before `oop`. `t1_fft2_name` in `scripts/common.sh` must produce the identical string.
3. Scripts: `common.sh` accepts both flags. The variants file accepts the `tp=` and `rx=` fields, which are validated and included in the duplicate-config key.
4. CPU tests: mirror the T2c tests for the new fields (label equality, dry-run flags, old files still parse).

## Constraints
- Touch only `bench/`, `scripts/`, `tests/`, and `docs/measurement.md`.
- Diff ≤ 200 lines, excluding tests.
- No performance claims. Follow the Coding principles in `CLAUDE.md`.

## Gate
- CPU: `pytest tests -q` and `shellcheck scripts/*.sh`.
- GPU (Claude, L4): a 2-variant sweep at 2^20 b1 (`tp=1 rx=1`) where every row is ok and the labels match.
