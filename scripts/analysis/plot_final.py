"""README figures and tables for a final T1 run (fft2 vs cuFFT vs VkFFT, hot median)."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from io_utils import number, read_csv

IMPLS = ["fft2", "cufft", "vkfft"]
NAMES = {"fft2": "fft2", "cufft": "cuFFT", "vkfft": "VkFFT"}
STYLE = {"fft2": dict(color="#D55E00", marker="o", lw=2.6, zorder=3),
         "cufft": dict(color="#4D4D4D", marker="s", lw=1.7, ls="--", zorder=2),
         "vkfft": dict(color="#7C9CBF", marker="^", lw=1.7, ls="-.", zorder=2)}
MODES = ["b1", "b8", "t25"]
LOG2S = list(range(16, 25))
plt.rcParams.update({"font.size": 12, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.titlesize": 14, "axes.titleweight": "bold", "axes.titlelocation": "left"})


def family(name: str) -> str:
    return name.split("[", 1)[0]


def load_times(root: Path) -> dict:
    """{(impl, mode, log2N): (time_us, N*batch)} from hot-median rows with status ok."""
    out = {}
    for r in read_csv(root / "sweep" / "raw.csv"):
        f, t = family(r["impl"]), number(r["time_ms_median"])
        if f in IMPLS and r["timing_mode"] == "hot" and r["status"] == "ok" and t:
            out.setdefault((f, r["batch_mode"], int(r["log2N"])), (t * 1000, int(r["N"]) * int(r["batch"])))
    return out


def load_kernels(root: Path, log2n: int, limits: dict) -> list[dict]:
    """Per-kernel rows (cache_control=all, batch 1) for one size, ordered by impl then launch."""
    rows = []
    for path in sorted((root / "ncu" / "summary").glob("*.csv")):
        for r in read_csv(path):
            f = family(r.get("impl", ""))
            if f not in IMPLS or r.get("cache_control") != "all" or r.get("batch") != "1" or int(r["N"]) != 1 << log2n:
                continue
            us, rd, wr, lts = (number(r.get(k)) for k in ("duration_us", "dram_read_bytes", "dram_write_bytes", "lts_bytes"))
            if not us:
                continue
            gbs = (rd + wr) / us / 1e3
            rows.append(dict(impl=f, order=r["kernel_id"], us=us, rd=rd / 1e6, wr=wr / 1e6, gbs=gbs,
                             pct_hbm=100 * gbs / limits["hbm_copy_GBs"],
                             pct_l2=100 * lts / us / 1e3 / limits["l2_copy_GBs_plateau"],
                             name="pass1" if "pass1" in r["kernel"] else "pass2" if "pass2" in r["kernel"] else ""))
    rows.sort(key=lambda r: (IMPLS.index(r["impl"]), [int(x) for x in r["order"].split(":")]))
    for impl in IMPLS:  # short labels: "fft2 pass1", "cuFFT k1"
        for i, r in enumerate(r for r in rows if r["impl"] == impl):
            r["label"] = f"{NAMES[impl]} {r['name'] or 'k%d' % (i + 1)}"
    return rows


def save(fig, out: Path, stem: str) -> None:
    fig.savefig(out / f"{stem}.svg", bbox_inches="tight")
    fig.savefig(out / f"{stem}.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def plot_bandwidth(times: dict, limits: dict, out: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 5), layout="constrained")
    l2_edge = math.log2(limits["l2_size_bytes"] / 32)  # in-place working set 2 * 16 B * N (repo definition)
    ax.axvspan(15.5, l2_edge, color="#E8EEF5", zorder=0)
    ax.axvline(l2_edge, color="#7C9CBF", ls="--", lw=1)
    for y, label in ((limits["hbm_copy_GBs"], "HBM copy (measured)"), (limits["l2_copy_GBs_plateau"], "L2 copy (measured)"),
                     (limits["hbm_copy_GBs"] / 2, "2-pass bound (HBM copy / 2)")):
        ax.axhline(y, color="#999999", ls=":", lw=1.5)
        ax.text(24.4, y, label, ha="right", va="bottom", color="#666666", fontsize=11)
    for impl in IMPLS:
        pts = [(k, 2 * times[(impl, "b1", k)][1] * 16 / times[(impl, "b1", k)][0] / 1e3)
               for k in LOG2S if (impl, "b1", k) in times]
        if pts:
            ax.plot(*zip(*pts), label=NAMES[impl], **STYLE[impl])
    ax.text(l2_edge + 0.08, 0.5, "L2 capacity", transform=ax.get_xaxis_transform(), color="#4F6D91", fontsize=11)
    ax.set_xlim(15.5, 24.5)
    ax.set_ylim(bottom=0)
    ax.set_xticks(LOG2S, [f"$2^{{{k}}}$" for k in LOG2S])
    ax.set_xlabel("N (complex128 points, batch 1)")
    ax.set_ylabel("effective GB/s (array read + written once)")
    ax.set_title("Effective bandwidth, batch 1 (A100)")
    ax.legend(loc="upper left", ncol=3, frameon=False, bbox_to_anchor=(0.0, 0.93))
    save(fig, out, "bandwidth_b1")


def plot_relative(times: dict, ref: str, out: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 2.8), layout="constrained")
    cmap = matplotlib.colormaps["PuOr"].copy()
    norm = matplotlib.colors.TwoSlopeNorm(vcenter=100, vmin=20, vmax=180)
    for i, mode in enumerate(MODES):
        for j, k in enumerate(LOG2S):
            a, b = times.get(("fft2", mode, k)), times.get((ref, mode, k))
            if not (a and b):
                ax.add_patch(plt.Rectangle((j - .5, i - .5), 1, 1, fill=False, ec="#DDDDDD"))
                continue
            v = 100 * b[0] / a[0]
            ax.add_patch(plt.Rectangle((j - .5, i - .5), 1, 1, fc=cmap(norm(v)), ec="white", lw=2))
            ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=12,
                    color="white" if v < 50 or v > 150 else "black")
    ax.set_xlim(-.5, len(LOG2S) - .5)
    ax.set_ylim(len(MODES) - .5, -.5)
    ax.set_xticks(range(len(LOG2S)), [f"$2^{{{k}}}$" for k in LOG2S])
    ax.set_yticks(range(len(MODES)), MODES)
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_xlabel("N")
    ax.set_title(f"fft2 speed as % of {NAMES[ref]}  (100 = equal, >100 = fft2 faster)")
    save(fig, out, f"relative_{ref}")


def plot_kernels(root: Path, limits: dict, out: Path) -> None:
    panels = [(k, load_kernels(root, k, limits)) for k in (20, 24)]
    panels = [p for p in panels if p[1]]
    if not panels:
        return
    fig, axes = plt.subplots(1, len(panels), figsize=(8, 3.6), layout="constrained", squeeze=False)
    for ax, (k, rows) in zip(axes[0], panels):
        key, what = ("pct_hbm", "% of HBM copy limit") if k == 24 else ("pct_l2", "% of L2 copy limit")
        ys = list(range(len(rows)))
        ax.barh(ys, [r[key] for r in rows], color=[STYLE[r["impl"]]["color"] for r in rows], height=.7)
        for y, r in zip(ys, rows):
            ax.text(r[key] + 1, y, f"{r[key]:.0f}%", va="center", fontsize=11)
        ax.set_yticks(ys, [r["label"] for r in rows])
        ax.invert_yaxis()
        ax.set_xlim(0, 100)
        ax.set_xlabel(what)
        ax.set_title(f"$2^{{{k}}}$, batch 1")
    save(fig, out, "kernels")


def fmt_table(head: list[str], rows: list[list[str]]) -> str:
    return "\n".join(["| " + " | ".join(head) + " |", "|" + "|".join("---" for _ in head) + "|"]
                     + ["| " + " | ".join(r) + " |" for r in rows]) + "\n"


def tables(root: Path, times: dict, limits: dict) -> str:
    rows = []
    for mode in MODES:
        for k in LOG2S:
            if not any((i, mode, k) in times for i in IMPLS):
                continue
            cells = [f"{times[(i, mode, k)][0]:.1f}" if (i, mode, k) in times else "-" for i in IMPLS]
            rel = [f"{100 * times[(r, mode, k)][0] / times[('fft2', mode, k)][0]:.0f}"
                   if ("fft2", mode, k) in times and (r, mode, k) in times else "-" for r in ("cufft", "vkfft")]
            rows.append([f"2^{k}", mode, *cells, *rel])
    text = ["## Hot median time (us)\n", fmt_table(["N", "batch", "fft2", "cuFFT", "VkFFT", "fft2 % of cuFFT", "fft2 % of VkFFT"], rows)]
    for k in (20, 24):
        kr = load_kernels(root, k, limits)
        if kr:
            text += [f"\n## Per-kernel (ncu), 2^{k}, batch 1\n", fmt_table(
                ["impl", "kernel", "time (us)", "DRAM read (MB)", "DRAM write (MB)", "achieved GB/s", "% HBM limit", "% L2 limit"],
                [[NAMES[r["impl"]], r["label"].split(" ", 1)[1], f"{r['us']:.1f}", f"{r['rd']:.1f}", f"{r['wr']:.1f}",
                  f"{r['gbs']:.0f}", f"{r['pct_hbm']:.0f}", f"{r['pct_l2']:.0f}"] for r in kr])]
    text.append("\nPercent columns: fft2 % of X = X time / fft2 time x 100. % HBM limit = (DRAM read + write) / kernel time "
                "over the measured HBM copy bandwidth; % L2 limit = LTS bytes / kernel time over the measured L2 copy plateau. "
                "At 2^20 DRAM bytes undercount traffic (writes deferred in L2), so judge that size by % L2.\n")
    return "\n".join(text)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("results_dir", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    limits = json.loads((a.results_dir / "bandwidth" / "limits.json").read_text())
    times = load_times(a.results_dir)
    plot_bandwidth(times, limits, a.out)
    for ref in ("cufft", "vkfft"):
        plot_relative(times, ref, a.out)
    plot_kernels(a.results_dir, limits, a.out)
    (a.out / "tables.md").write_text(tables(a.results_dir, times, limits), encoding="utf-8")


if __name__ == "__main__":
    main()
