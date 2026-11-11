"""Plot only verified-correct sweep rows; retain every status in the summary."""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from io_utils import md_table, positive, read_csv

# Okabe-Ito palette. Backend colors are stable across every figure.
COLORS = {"legacy": "#D55E00", "cufft": "#0072B2", "vkfft": "#009E73", "fft2": "#CC79A7"}
EXTRA_COLORS = ["#E69F00", "#56B4E9", "#000000"]
MARKERS = ["o", "s", "^", "v", "D", "P", "X"]
LINESTYLES = ["-", "--", "-.", ":"]


def series_styles(rows: list[dict]) -> dict[str, dict]:
    implementations = sorted({r["impl"] for r in rows})
    families = sorted({impl.split("[", 1)[0] for impl in implementations})
    colors = dict(COLORS)
    for i, family in enumerate(f for f in families if f not in colors):
        colors[family] = EXTRA_COLORS[i % len(EXTRA_COLORS)]
    styles = {}
    for family in families:
        for i, impl in enumerate(name for name in implementations if name.split("[", 1)[0] == family):
            styles[impl] = {"color": colors[family], "marker": MARKERS[i % len(MARKERS)],
                            "linestyle": LINESTYLES[(i // len(MARKERS)) % len(LINESTYLES)]}
    return styles


def plot(rows: list[dict], output_dir: Path, summary: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = [{"impl_detail": "", **row} for row in rows]
    styles = series_styles(rows)
    paths = []
    text = ["# FFT measurement summary\n",
            "Times and floors come from this run. Plots include only rows with status=ok. "
            "Percent of cuFFT is cuFFT time / implementation time × 100; higher is faster.\n"]
    for batch_mode, timing in sorted({(r["batch_mode"], r["timing_mode"]) for r in rows}):
        subset = sorted([r for r in rows if (r["batch_mode"], r["timing_mode"]) == (batch_mode, timing)],
                        key=lambda r: (int(r["N"]), r["impl"]))
        text.append(f"## {batch_mode}, {timing}\n")
        text.append(md_table(subset, ["impl", "impl_detail", "N", "batch", "time_ms_median", "t_pass_ms", "pass_equiv",
                                      "pct_of_cufft", "rel_l2_err", "max_abs_err", "status", "note"]))
        for metric, label, suffix in [("time_ms_median", "Time (ms)", "time"),
                                      ("pass_equiv", "Time / measured in-place pass floor", "passes"),
                                      ("pct_of_cufft", "% of cuFFT (higher is faster)", "cufft")]:
            path = output_dir / f"{batch_mode}_{timing}_{suffix}.png"
            if path.exists():
                raise FileExistsError(f"refusing to overwrite {path}")
            fig, ax = plt.subplots(figsize=(8, 5), layout="constrained")
            for impl in sorted({r["impl"] for r in subset}):
                series = [r for r in subset if r["impl"] == impl and r["status"] == "ok" and positive(r.get(metric)) is not None]
                if series:
                    ax.plot([int(r["N"]) for r in series], [float(r[metric]) for r in series],
                            **styles[impl], label=impl)
            if metric == "time_ms_median":
                floors = {}
                for row in subset:
                    value = positive(row.get("t_pass_ms"))
                    if row["status"] == "ok" and value is not None:
                        floors[int(row["N"])] = value
                ns = sorted(floors)
                if ns:
                    ax.plot(ns, [floors[n] for n in ns], "--", color="#666666", label="1-pass floor")
                    ax.plot(ns, [2 * floors[n] for n in ns], "--", color="#999999", label="2-pass floor")
                ax.set_yscale("log")
            elif metric == "pct_of_cufft":
                ax.axhline(100, color="#999999", linestyle=":", linewidth=1)
            ax.set_xscale("log", base=2)
            ax.set(xlabel="N (complex doubles per FFT)", ylabel=label, title=f"{batch_mode} · {timing}")
            ax.grid(True, which="both", alpha=.25)
            handles, _ = ax.get_legend_handles_labels()
            if handles:
                ax.legend()
            fig.savefig(path, dpi=160)
            plt.close(fig)
            paths.append(path)
    summary.parent.mkdir(parents=True, exist_ok=True)
    with summary.open("x", encoding="utf-8") as stream:
        stream.write("\n".join(text))
    return paths


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--plots", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    args = parser.parse_args(argv)
    plot(read_csv(args.input), args.plots, args.summary)


if __name__ == "__main__":
    main()
