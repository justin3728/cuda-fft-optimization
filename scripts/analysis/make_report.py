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
ABSENT = {"", "na", "n/a", "null", "nan", "not supported"}


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
        self.total_file = self.summary_file("config_totals.csv")
        self.totals = self.rows(self.total_file)
        self.calibration_file = self.summary_file("copy_calibration.csv")
        self.calibrations = self.rows(self.calibration_file)

    def source(self, relative):
        return f"results/{self.tag}/{relative}"

    def summary_file(self, name):
        modern = f"ncu/summary/{name}"
        return modern if (self.root / modern).is_file() else f"ncu/{name}"

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


def header(run, md, title="Measurement report", level=1):
    metadata = run.metadata()
    gpu = metadata["GPU"]
    official = not isinstance(gpu, Missing) and str(gpu).removeprefix("NVIDIA ") == "A100-SXM4-40GB"
    output = f"{'#' * level} {title}: {md.cell(run.tag)}\n\n"
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
    output += ("Gap = implementation time − calibrated DRAM passes × pass floor; gap (%) = "
               "100 × gap / implementation time. Passes come from config_totals.csv, with "
               "copy_calibration.csv required. Hot uses cache_control=none; cold uses all. "
               "These ncu replay policies differ from the sweep's cache handling, so this is "
               "an observed-traffic floor comparison, not an inferred algorithmic pass count. "
               "Sampled/extrapolated totals are unavailable for gaps. "
               "For L2-resident configs, deferred DRAM writes undercount passes; judge the "
               "per-kernel L2 metrics. Negative gaps are retained.\n\n")
    columns = ["N", "Batch", "Batch label", "Impl"]
    has_detail = any("impl_detail" in row.data for row in run.sweeps)
    if has_detail:
        columns += ["impl_detail"]
    columns += ["Timing", "Median (µs)", "Speedup vs cuFFT (×)", "Passes-equivalent", "Correctness status",
                "Calibrated DRAM passes", "Gap (µs)", "Gap (%)"]
    rows = []
    for row in sweep_entries(run, impls):
        time = eligible_time(row)
        values = [row.value(field) for field in (*CONFIG, "impl")]
        if has_detail:
            values += [row.value("impl_detail")]
        values += [row.value("timing_mode"), calc(lambda ms: ms * 1000, row.numeric("time_ms_median", positive=True)),
                   calc(lambda reference, ms: reference / ms, cufft_time(run, row), time),
                   calc(lambda ms, floor: ms / floor, time, pass_floor(run, row)), row.value("status")]
        values += list(gap_values(run, row))
        rows.append(values)
    if not rows:
        rows = [[run.missing(run.sweep_file, "sweep rows")] * len(columns)]
    return output + md.table(columns, rows)


PROFILE = ("impl", *CONFIG, "cache_control")
L2_NOTE = "DRAM bytes undercount traffic (writes deferred in L2); judge this config by L2 metrics."


def markdown_kernels(run, relative):
    """Read the first per-kernel table in the compact, pre-fix smoke exports."""
    fields = None
    rows = []
    for line_no, line in enumerate(run.text(relative).splitlines(), 1):
        if not line.startswith("|"):
            if rows:
                break
            continue
        values = [html.unescape(value.strip().replace(r"\|", "|"))
                  for value in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if fields is None:
            if "kernel" in values:
                fields = values
            continue
        if all(re.fullmatch(r":?-+:?", value) for value in values):
            continue
        if len(values) != len(fields):
            raise ValueError(f"{run.source(relative)} line {line_no}: malformed kernel table")
        rows.append(Record(dict(zip(fields, values)), f"{run.source(relative)} line {line_no}"))
    return rows


@dataclass
class Profile:
    config: Record
    kernels: list[Record]
    total: Record


def profile_key(row):
    identity = key(row, PROFILE)
    return (*identity, detail(row)) if identity is not None else None


def profiles(run, impls):
    groups = {}
    # Prefer modern normalized CSV to Markdown; never parse a raw ncu metric CSV
    # as a normalized summary, and never double-count sibling CSV/Markdown files.
    seen_stems = set()
    for directory in ("ncu/summary", "ncu"):
        for extension in ("csv", "md"):
            for path in sorted((run.root / directory).glob(f"*.{extension}")):
                if path.stem in seen_stems or path.name in {"config_totals.csv", "copy_calibration.csv", "index.csv"}:
                    continue
                relative = path.relative_to(run.root).as_posix()
                rows = run.rows(relative) if extension == "csv" else markdown_kernels(run, relative)
                if not rows or "kernel" not in rows[0].data:
                    continue
                seen_stems.add(path.stem)
                for row in rows:
                    if row.data.get("impl") not in impls:
                        continue
                    identity = profile_key(row) or (row.source,)
                    groups.setdefault(identity, Profile(row, [], Record({}, run.source(run.total_file))))
                    groups[identity].kernels.append(row)
    totals = indexed(run.totals, PROFILE, variants=True)
    for entry in [*run.totals, *run.rows("ncu/index.csv")]:
        if entry.data.get("impl") not in impls:
            continue
        identity = profile_key(entry) or (entry.source,)
        groups.setdefault(identity, Profile(entry, [], Record({}, run.source(run.total_file))))
    for identity, profile in groups.items():
        profile.total = totals.get(identity, profile.total)
        indexed(profile.kernels, ("kernel_id",))
    return sorted(groups.values(), key=lambda profile: config_sort(
        tuple(str(profile.config.data.get(field, "")) for field in (*CONFIG, "impl", "cache_control"))
        + (detail(profile.config),)))


def calibration_factor(run):
    rows = [row for row in run.calibrations
            if row.numeric("working_set_MiB") == 4096 and row.data.get("cache_control") == "all"]
    if len(rows) > 1:
        raise ValueError(f"{run.source(run.calibration_file)}: duplicate HBM copy calibration")
    return rows[0].numeric("dram_traffic_factor", positive=True) if rows else run.missing(
        run.calibration_file, "dram_traffic_factor for working_set_MiB=4096, cache_control=all")


def traffic_passes(run, row):
    identity = key(row, ("impl", *CONFIG))
    cache = {"hot": "none", "cold": "all"}.get(row.data.get("timing_mode"))
    total_key = (*identity, cache, detail(row)) if identity is not None and cache else None
    total = indexed(run.totals, PROFILE, variants=True).get(total_key)
    if total is None:
        return run.missing(run.total_file, f"calibrated_memory_passes for {total_key}")
    if any(str(total.data.get(field, "")).lower() in {"true", "1", "yes"}
           for field in ("sampled", "totals_extrapolated")):
        return Missing((f"{total.source}: sampled/extrapolated totals cannot supply a measured gap",))
    factor = calibration_factor(run)
    if "calibrated_memory_passes" in total.data:
        return calc(lambda passes, calibration: passes, total.numeric("calibrated_memory_passes"), factor)
    return calc(lambda raw, calibration: raw / calibration, total.numeric("effective_memory_passes"), factor)


def gap_values(run, row):
    passes = traffic_passes(run, row)
    time = eligible_time(row)
    floor = pass_floor(run, row)
    gap_us = calc(lambda ms, count, pass_ms: (ms - count * pass_ms) * 1000, time, passes, floor)
    gap_pct = calc(lambda gap, ms: gap / (ms * 1000) * 100, gap_us, time)
    return passes, gap_us, gap_pct


def fits_l2(run, config):
    if "working_set_fits_l2" in config.data:
        value = config.value("working_set_fits_l2")
        if isinstance(value, Missing):
            return value
        if str(value).lower() in {"true", "1", "yes"}:
            return True
        if str(value).lower() in {"false", "0", "no"}:
            return False
        return Missing((f"{config.source}: invalid working_set_fits_l2 ({value!r})",))
    return calc(lambda n, batch, size: 32 * n * batch <= size,
                config.numeric("N", positive=True), config.numeric("batch", positive=True),
                run.limits.numeric("l2_size_bytes", positive=True))


def kernel_metrics(run, row):
    read = row.numeric("dram_read_bytes")
    write = row.numeric("dram_write_bytes")
    time = row.numeric("duration_us", positive=True)
    ideal = calc(lambda n, batch: 16 * n * batch, row.numeric("N", positive=True), row.numeric("batch", positive=True))
    factor = calibration_factor(run)
    mixed = row.numeric("pct_mixed_hbm_limit") if "pct_mixed_hbm_limit" in row.data else calc(
        lambda r, w, rd, wr, us: 100 * (r / (1000 * rd) + w / (1000 * wr)) / us,
        read, write, run.limits.numeric("hbm_read_GBs", positive=True),
        run.limits.numeric("hbm_write_GBs", positive=True), time)
    l2 = row.numeric("pct_l2_limit") if "pct_l2_limit" in row.data else calc(
        lambda traffic, limit, us: 100 * traffic / (1000 * limit * us),
        row.numeric("lts_bytes"), run.limits.numeric("l2_read_GBs_plateau", positive=True), time)
    return {
        "read_ratio": calc(lambda traffic, calibration, payload: traffic / calibration / payload, read, factor, ideal),
        "write_ratio": calc(lambda traffic, calibration, payload: traffic / calibration / payload, write, factor, ideal),
        "mixed": mixed, "l2": l2,
    }


def kernels_section(run, md, impls):
    output = ("## Per-kernel profiles\n\n"
              "NCU replay durations are distinct from sweep times. DRAM R/ideal and W/ideal "
              "divide observed bytes by the same-GPU HBM-copy traffic factor and by "
              "16 × N × batch bytes per direction. Percentages retain observed counter traffic, "
              "without calibration or clipping. Older tables without the percentage columns use "
              "100 × (R/(1000 × HBM read GB/s) + W/(1000 × HBM write GB/s)) / duration_us and "
              "100 × L2 bytes / (1000 × L2 read plateau GB/s × duration_us). "
              "A present but unavailable percentage remains n/a.\n\n")
    output += md.table(["Calibration source", "HBM-copy DRAM traffic factor"],
                       [(run.source(run.calibration_file), calibration_factor(run))])
    items = profiles(run, impls)
    if not items:
        return output + md.table(["Profiles"], [[run.missing(
            "ncu/summary/*.csv (or ncu/*_N*.md)", "per-kernel profile rows")]])
    for profile in items:
        config = profile.config
        label = ", ".join(f"{field}={md.cell(config.value(field))}" for field in PROFILE)
        if detail(config):
            label += f", impl_detail={md.cell(config.value('impl_detail'))}"
        output += f"### {label}\n\nSource: `{config.source}`.\n\n"
        resident = fits_l2(run, config)
        output += f"working_set_fits_l2: {md.cell(resident)} (two-buffer proxy: 32 × N × batch ≤ L2 size).\n\n"
        if resident is True:
            output += f"> **L2-resident:** {L2_NOTE}\n\n"
        if "sampled" in config.data or "sampled" in profile.total.data:
            capture = profile.total if "sampled" in profile.total.data else config
            output += md.table(["Sampled", "Captured kernels", "Expected kernels", "Stored totals extrapolated"],
                               [[capture.value(field) for field in ("sampled", "captured_kernels", "expected_kernels", "totals_extrapolated")]])
            output += "Per-kernel values are captured values; this report never scales sampled launches.\n\n"
        columns = ["Kernel ID", "Kernel", "Time (µs)", "DRAM read (B)", "DRAM write (B)",
                   "DRAM R/ideal (cal.)", "DRAM W/ideal (cal.)", "L2 bytes", "pct_mixed_hbm_limit",
                   "pct_l2_limit", "Achieved occupancy (%)", "Bank conflicts ld", "Bank conflicts st",
                   "Stall 1", "Stall 1 (%)", "Stall 2", "Stall 2 (%)"]
        rows = []
        for row in profile.kernels:
            metrics = kernel_metrics(run, row)
            rows.append([row.value("kernel_id"), row.value("kernel"), row.numeric("duration_us", positive=True),
                         row.numeric("dram_read_bytes"), row.numeric("dram_write_bytes"),
                         metrics["read_ratio"], metrics["write_ratio"], row.numeric("lts_bytes"),
                         metrics["mixed"], metrics["l2"], row.numeric("achieved_occupancy_pct"),
                         row.numeric("shared_bank_conflicts_ld"), row.numeric("shared_bank_conflicts_st"),
                         row.value("stall_1"), row.numeric("stall_1_pct"), row.value("stall_2"), row.numeric("stall_2_pct")])
        if not rows:
            rows = [[run.missing("ncu/summary/", f"kernel rows for {key(config, PROFILE)}")] * len(columns)]
        output += md.table(columns, rows)
    return output


def comparison_section(current, baseline, md, impls):
    output = "## Before / after\n\n"
    output += header(baseline, md, title="Baseline environment", level=3)
    output += (f"Before: `{baseline.source(baseline.sweep_file)}`. "
               f"After: `{current.source(current.sweep_file)}`. "
               "Only exact shared (N, batch, batch label, impl, impl_detail, timing mode) keys "
               "are compared. An absent impl_detail matches an empty detail. "
               "Delta = after − before; delta (%) = 100 × delta / before. "
               "Negative time deltas mean less elapsed time. Deltas require both statuses to be ok.\n\n")
    fields = (*CONFIG, "impl", "timing_mode")
    old = indexed(baseline.sweeps, fields, variants=True)
    new = indexed(current.sweeps, fields, variants=True)
    has_detail = any("impl_detail" in row.data for row in [*baseline.sweeps, *current.sweeps])
    columns = ["N", "Batch", "Batch label", "Impl"] + (["impl_detail"] if has_detail else [])
    columns += ["Timing", "Before (µs)", "After (µs)", "Delta (µs)", "Delta (%)", "Before status", "After status"]
    rows = []
    for identity in sorted(old.keys() & new.keys(), key=config_sort):
        before, after = old[identity], new[identity]
        if after.data.get("impl") not in impls:
            continue
        values = [after.value(field) for field in (*CONFIG, "impl")]
        if has_detail:
            values += [after.value("impl_detail")]
        delta = calc(lambda now, then: (now - then) * 1000, eligible_time(after), eligible_time(before))
        values += [after.value("timing_mode"),
                   calc(lambda ms: ms * 1000, before.numeric("time_ms_median", positive=True)),
                   calc(lambda ms: ms * 1000, after.numeric("time_ms_median", positive=True)),
                   delta, calc(lambda us, ms: us / (ms * 1000) * 100, delta, eligible_time(before)),
                   before.value("status"), after.value("status")]
        rows.append(values)
    if not rows:
        reason = Missing((f"{baseline.source(baseline.sweep_file)} and {current.source(current.sweep_file)}: "
                          "missing shared requested sweep configurations",))
        rows = [[reason] * len(columns)]
    return output + md.table(columns, rows)


def generate_report(results_root, tag, *, baseline_tag=None, impls=IMPLEMENTATIONS, plots=False, out=None):
    md = Markdown()
    run = Run(results_root, tag)
    output = (header(run, md) + limits_section(run, md) + sweep_section(run, md, impls)
              + kernels_section(run, md, impls))
    if baseline_tag:
        output += comparison_section(run, Run(results_root, baseline_tag), md, impls)
    return output + md.footnotes()


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
