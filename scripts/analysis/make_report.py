"""Render an auditable Markdown report from existing measurement files only."""
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
import html
import json
import os
from pathlib import Path
import re
import sys

from io_utils import number

ROOT = Path(__file__).resolve().parents[2]
IMPLEMENTATIONS = ("legacy", "cufft", "vkfft", "fft2")
ABSENT = {"", "na", "n/a", "none", "null", "nan", "not supported"}


@dataclass(frozen=True)
class Missing:
    reasons: tuple[str, ...]


@dataclass
class Record:
    data: dict
    source: str

    def value(self, column):
        value = self.data.get(column)
        if value is None or str(value).strip().lower() in ABSENT:
            return Missing((f"{self.source}: missing {column}",))
        return value

    def numeric(self, column, *, positive=False):
        value = self.value(column)
        if isinstance(value, Missing):
            return value
        result = number(value)
        if result is None or (positive and result <= 0):
            return Missing((f"{self.source}: invalid {column} ({value!r})",))
        return result


def calc(function, *values):
    reasons = tuple(dict.fromkeys(reason for value in values if isinstance(value, Missing)
                                 for reason in value.reasons))
    if reasons:
        return Missing(reasons)
    return function(*values)


class Markdown:
    def __init__(self):
        self.notes = {}

    def cell(self, value):
        if isinstance(value, Missing):
            references = []
            for reason in value.reasons:
                self.notes.setdefault(reason, len(self.notes) + 1)
                references.append(f"[^missing-{self.notes[reason]}]")
            return "n/a" + "".join(references)
        if isinstance(value, float):
            value = f"{value:.6g}"
        return html.escape(str(value), quote=False).replace("|", r"\|").replace("\n", " ")

    def table(self, columns, rows):
        lines = ["| " + " | ".join(columns) + " |",
                 "| " + " | ".join("---" for _ in columns) + " |"]
        lines += ["| " + " | ".join(self.cell(value) for value in row) + " |" for row in rows]
        return "\n".join(lines) + "\n\n"

    def footnotes(self):
        if not self.notes:
            return ""
        return "## Missing data\n\n" + "\n".join(
            f"[^missing-{index}]: {self.cell(reason)}." for reason, index in self.notes.items()) + "\n"


class Run:
    def __init__(self, results_root, tag):
        self.tag = tag
        self.root = Path(results_root) / tag
        self.limits = Record(self.json("bandwidth/limits.json"), self.source("bandwidth/limits.json"))
        self.sweep_file = ("sweep/raw.csv" if (self.root / "sweep/raw.csv").is_file()
                           or not (self.root / "sweep/derived.csv").is_file() else "sweep/derived.csv")
        self.sweeps = self.rows(self.sweep_file)
        self.floors = self.rows("bandwidth/pass_floor.csv")

    def source(self, relative):
        return f"results/{self.tag}/{relative}"

    def text(self, relative):
        path = self.root / relative
        return path.read_text(encoding="utf-8-sig") if path.is_file() else ""

    def json(self, relative):
        text = self.text(relative)
        if not text.strip():
            return {}
        data = json.loads(text)
        if not isinstance(data, dict):
            raise ValueError(f"{self.source(relative)}: expected a JSON object")
        return data

    def rows(self, relative):
        path = self.root / relative
        if not path.is_file():
            return []
        with path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            return [Record(dict(row), f"{self.source(relative)} row {index}")
                    for index, row in enumerate(reader, 2)]

    def missing(self, relative, column):
        return Missing((f"{self.source(relative)}: missing {column}",))

    def metadata(self):
        env = self.text("env.txt")
        index = self.rows("ncu/index.csv")
        commands = self.text("ncu/commands.txt")

        def find(field, pattern, *, text=env, alternatives=()):
            match = re.search(pattern, text, re.MULTILINE | re.IGNORECASE)
            if match and match.group(1).strip().lower() not in ABSENT:
                return match.group(1).strip()
            for name in (field, *alternatives):
                value = self.limits.value(name)
                if not isinstance(value, Missing):
                    return value
            return Missing((f"{self.source('env.txt')}: missing {field}; "
                            f"{self.limits.source}: missing {field}",))

        def settings(column, option):
            values = {str(row.data[column]) for row in index
                      if row.data.get(column, "").strip().lower() not in ABSENT}
            values.update(re.findall(rf"--{option}(?:=|\s+)([\w.-]+)", commands))
            return ", ".join(sorted(values)) if values else Missing((
                f"{self.source('ncu/index.csv')}:{column} and "
                f"{self.source('ncu/commands.txt')}:--{option} missing",))

        clock_block = re.search(r"^(\s*)Clocks\s*\n((?:(?:[ \t]+[^\n]*)?\n)*)", env, re.MULTILINE)
        clocks = {}
        if clock_block:
            indent = len(clock_block.group(1))
            for line in clock_block.group(2).splitlines():
                if line.strip() and len(line) - len(line.lstrip()) <= indent:
                    break
                match = re.match(r"\s*(Graphics|SM|Memory)\s*:\s*(.+)", line)
                if match:
                    clocks[match.group(1).lower()] = match.group(2).strip()
        version = self.text("ncu/version.txt")
        ncu = find("ncu_version", r"^\s*(?:Nsight Compute(?: CLI)?(?: version)?|Version)\s*[: ]\s*([\d.]+)",
                   text=version or env)
        return {
            "GPU": find("gpu_name", r"^\s*(?:Product Name|GPU name)\s*:\s*(.+)", alternatives=("gpu", "device_name")),
            "Driver": find("driver_version", r"^\s*Driver Version\s*:\s*(.+)"),
            "CUDA toolkit": find("cuda_version", r"Cuda compilation tools, release\s+([\d.]+)"),
            "Nsight Compute": ncu,
            "Date captured": find("date", r"^(\d{4}-\d\d-\d\dT\S+)", alternatives=("timestamp",)),
            "Current SM clock": clocks.get("sm", self.missing("env.txt", "Clocks/SM")),
            "Current graphics clock": clocks.get("graphics", self.missing("env.txt", "Clocks/Graphics")),
            "Current memory clock": clocks.get("memory", self.missing("env.txt", "Clocks/Memory")),
            "ncu cache control": settings("cache_control", "cache-control"),
            "ncu clock control": settings("clock_control", "clock-control"),
        }


def header(run, md, title="Measurement report"):
    metadata = run.metadata()
    gpu = metadata["GPU"]
    official = not isinstance(gpu, Missing) and str(gpu).removeprefix("NVIDIA ") == "A100-SXM4-40GB"
    output = f"# {title}: {md.cell(run.tag)}\n\n"
    if not official:
        output += ("> [!WARNING]\n> **smoke test, not official numbers** — "
                   "GPU is not verified as A100-SXM4-40GB.\n\n")
    output += md.table(["Environment", "Captured value"], metadata.items())
    return output


def limits_section(run, md):
    output = "## Measured limits\n\n"
    output += f"Source: `{run.limits.source}`. Bandwidth uses decimal GB/s.\n\n"
    fields = [("HBM read (GB/s)", "hbm_read_GBs"),
              ("HBM write (GB/s)", "hbm_write_GBs"),
              ("HBM copy, read + write (GB/s)", "hbm_copy_GBs"),
              ("L2 read plateau (GB/s)", "l2_read_GBs_plateau"),
              ("L2 copy plateau (GB/s)", "l2_copy_GBs_plateau"),
              ("L2 size (bytes)", "l2_size_bytes")]
    output += md.table(["Measurement", "Value"],
                       [(label, run.limits.numeric(field, positive=True)) for label, field in fields]
                       + [("L2 plateau range (MiB)", run.limits.value("l2_plateau_range_MiB")),
                          ("L2 plateau rule", run.limits.value("l2_plateau_rule"))])
    output += f"### Per-size pass floors\n\nSource: `{run.source('bandwidth/pass_floor.csv')}`.\n\n"
    rows = []
    for row in run.floors:
        rows.append([row.value(field) for field in ("N", "batch", "batch_mode", "timing_mode", "copy_kind")]
                    + [calc(lambda ms: ms * 1000, row.numeric("time_ms_median", positive=True)),
                       row.value("status")])
    if not rows:
        rows = [[run.missing("bandwidth/pass_floor.csv", "pass-floor rows")]]
        rows[0] *= 7
    output += md.table(["N", "Batch", "Batch label", "Timing", "Copy kind", "Median (µs)", "Status"], rows)
    return output


CONFIG = ("N", "batch", "batch_mode")


def key(row, fields):
    values = tuple(row.value(field) for field in fields)
    if any(isinstance(value, Missing) for value in values):
        return None
    return tuple(str(value) for value in values)


def detail(row):
    value = row.value("impl_detail")
    return "" if isinstance(value, Missing) else str(value)


def indexed(rows, fields, *, variants=False):
    output = {}
    for row in rows:
        identity = key(row, fields)
        if identity is None:
            continue
        if variants:
            identity += (detail(row),)
        if identity in output:
            raise ValueError(f"duplicate join key {identity}: {output[identity].source} and {row.source}")
        output[identity] = row
    return output


def config_sort(identity):
    return tuple((0, number(value)) if number(value) is not None else (1, str(value)) for value in identity)


def sweep_entries(run, impls):
    rows = indexed(run.sweeps, (*CONFIG, "impl", "timing_mode"), variants=True)
    configs = {key(row, CONFIG) for row in run.sweeps if key(row, CONFIG) is not None}
    output = []
    for config in sorted(configs, key=config_sort):
        for impl in impls:
            variants = sorted({detail(row) for row in run.sweeps
                               if key(row, CONFIG) == config and row.data.get("impl") == impl}) or [""]
            for variant in variants:
                for timing in ("hot", "cold"):
                    identity = (*config, impl, timing, variant)
                    absent = Record(dict(zip((*CONFIG, "impl", "timing_mode"), (*config, impl, timing))),
                                    f"{run.source(run.sweep_file)} ({', '.join(identity)})")
                    output.append(rows.get(identity, absent))
    # Incomplete identities remain visible; they cannot join another missing key.
    output += [row for row in run.sweeps
               if key(row, CONFIG) is None and row.data.get("impl") in impls]
    return output


def eligible_time(row):
    if row.data.get("status") != "ok":
        return Missing((f"{row.source}: status={row.data.get('status', 'missing')}; derived metrics require ok",))
    return row.numeric("time_ms_median", positive=True)


def pass_floor(run, row):
    floors = indexed([item for item in run.floors if item.data.get("copy_kind") == "inplace"],
                     (*CONFIG, "timing_mode"))
    identity = key(row, (*CONFIG, "timing_mode"))
    floor = floors.get(identity) if identity is not None else None
    if floor is None:
        return run.missing("bandwidth/pass_floor.csv", f"inplace time_ms_median for {identity}")
    return eligible_time(floor)


def cufft_time(run, row):
    identity = key(row, (*CONFIG, "timing_mode"))
    candidates = [item for item in run.sweeps if identity is not None
                  and key(item, (*CONFIG, "timing_mode")) == identity and item.data.get("impl") == "cufft"]
    if len(candidates) != 1:
        return run.missing(run.sweep_file, f"unique cufft time_ms_median for {identity}")
    return eligible_time(candidates[0])


def sweep_section(run, md, impls):
    output = "## FFT sweep\n\n"
    output += (f"Source: `{run.source(run.sweep_file)}`. Times are unprofiled medians. "
               "Speedup = cuFFT time / implementation time; passes-equivalent = time / "
               "same-config, same-mode in-place pass floor. Derived metrics require status=ok.\n\n")
    columns = ["N", "Batch", "Batch label", "Impl"]
    has_detail = any("impl_detail" in row.data for row in run.sweeps)
    if has_detail:
        columns += ["impl_detail"]
    columns += ["Timing", "Median (µs)", "Speedup vs cuFFT (×)", "Passes-equivalent", "Correctness status"]
    rows = []
    for row in sweep_entries(run, impls):
        time = eligible_time(row)
        values = [row.value(field) for field in (*CONFIG, "impl")]
        if has_detail:
            values += [row.value("impl_detail")]
        values += [row.value("timing_mode"), calc(lambda ms: ms * 1000, row.numeric("time_ms_median", positive=True)),
                   calc(lambda reference, ms: reference / ms, cufft_time(run, row), time),
                   calc(lambda ms, floor: ms / floor, time, pass_floor(run, row)), row.value("status")]
        rows.append(values)
    if not rows:
        rows = [[run.missing(run.sweep_file, "sweep rows")] * len(columns)]
    return output + md.table(columns, rows)


def generate_report(results_root, tag, *, baseline_tag=None, impls=IMPLEMENTATIONS, plots=False, out=None):
    md = Markdown()
    run = Run(results_root, tag)
    return header(run, md) + limits_section(run, md) + sweep_section(run, md, impls) + md.footnotes()


def safe_tag(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", value):
        raise argparse.ArgumentTypeError("tag must be one safe directory name")
    return value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, type=safe_tag)
    parser.add_argument("--baseline-tag", type=safe_tag)
    parser.add_argument("--impls", default=",".join(IMPLEMENTATIONS))
    parser.add_argument("--out", type=Path)
    parser.add_argument("--plots", action="store_true")
    parser.add_argument("--results-root", type=Path, default=ROOT / "results")
    args = parser.parse_args(argv)
    impls = tuple(dict.fromkeys(args.impls.split(",")))
    if not impls or any(impl not in IMPLEMENTATIONS for impl in impls):
        parser.error("--impls must be a comma-separated subset of " + ",".join(IMPLEMENTATIONS))
    if args.out and args.out.resolve().is_relative_to(args.results_root.resolve()):
        parser.error("--out must be outside the input results directory")
    try:
        report = generate_report(args.results_root, args.tag, baseline_tag=args.baseline_tag,
                                 impls=impls, plots=args.plots, out=args.out)
        if args.out:
            with args.out.open("x", encoding="utf-8") as stream:
                stream.write(report)
        else:
            sys.stdout.write(report)
    except (OSError, ValueError) as error:
        parser.exit(1, f"make_report: {error}\n")


if __name__ == "__main__":
    main()
