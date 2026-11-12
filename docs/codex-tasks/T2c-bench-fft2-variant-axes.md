# Codex Task T2c — expose T4a variant axes in the bench and variants runner

> Paste everything below the line into Codex. Create branch **`codex/t2c-variant-axes` from `main`**, open a draft PR. Small task (~1–2 hours).

---

## Context
`main` now has T2b (fft2 as a bench backend, `scripts/run_fft2_variants.sh`) and T4a (`fft2::PlanOptions::index_mode` ∈ {0,1}, `smem_padding` ∈ {0,1,2}). The bench can only set `n1`, `tile_cols`, `tile_rows`, out-of-place, so H9/H10 cannot be A/B'd in the same A100 allocation as the tile sweep.

## Hard constraints
1. Do not modify `fft2/`, protected legacy files, `results/`, `docs/plan.md`.
2. Touch only `bench/`, `scripts/` (incl. `scripts/analysis/` if needed), `tests/`, `docs/measurement.md`. Commit and push after each item. No performance claims.

## Deliverables
1. `fft_bench`: `--fft2-index-mode M`, `--fft2-smem-padding P` (default 0) into `PlanOptions`; forwarded by the sweep driver to workers like the other fft2 flags.
2. Label: append `,im=M` / `,pad=P` to `fft2_name()` **only when nonzero**, so existing labels such as `fft2[n1=0,c=0,r=0]` stay unchanged. `t1_fft2_name` in `scripts/common.sh` must produce the identical string (NVTX filter depends on it).
3. Scripts: `common.sh` accepts both flags; variants file accepts `im=` and `pad=` fields (validated like the others, included in the duplicate-config key).
4. Tests (CPU): label equality between C++ format and `t1_fft2_name` for a few combinations (parse the C++ format string or mirror it in a test); variants dry-run with `im=1 pad=1` produces the expected flags; old variant files still parse.

## Gate
`pytest tests -q`, `shellcheck scripts/*.sh`, `make bench TAG=t2c CUDA_ARCH=sm_80` zero warnings.
