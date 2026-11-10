"""Normalize Nsight Compute raw CSV exports, preserving missing values as NA."""
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
import json
from pathlib import Path
import re
import shutil
import tempfile
import warnings

from io_utils import md_table, number, positive, read_csv, write_csv

METRICS = {
    "duration_us": ["gpu__time_duration.sum"],
    "dram_read_bytes": ["dram__bytes_read.sum"],
    "dram_write_bytes": ["dram__bytes_write.sum"],
    "lts_bytes": ["lts__t_bytes.sum"],
    "registers_per_thread": ["launch__registers_per_thread"],
    "static_smem_bytes": ["launch__shared_mem_per_block_static"],
    "dynamic_smem_bytes": ["launch__shared_mem_per_block_dynamic"],
    "theoretical_occupancy_pct": ["sm__maximum_warps_per_active_cycle_pct"],
    "achieved_occupancy_pct": ["sm__warps_active.avg.pct_of_peak_sustained_active"],
    "shared_bank_conflicts_ld": ["l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum"],
    "shared_bank_conflicts_st": ["l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_st.sum"],
    "fp64_pipe_util_pct": ["sm__pipe_fp64_cycles_active.avg.pct_of_peak_sustained_active"],
}
EXTRA_METRICS = ["launch__grid_size", "launch__block_size", "lts__t_sectors.sum"]
FIELDS = ["impl", "N", "batch", "batch_mode", "cache_control", "kernel_id", "kernel", "grid", "block",
          "registers_per_thread", "static_smem_bytes", "dynamic_smem_bytes", "smem_bytes", "duration_us",
          "pct_config_time", "dram_read_bytes", "dram_write_bytes", "lts_bytes", "dram_GBs",
          "pct_measured_hbm_copy", "l2_GBs", "pct_measured_l2_copy", "theoretical_occupancy_pct",
          "achieved_occupancy_pct", "shared_bank_conflicts_ld", "shared_bank_conflicts_st", "fp64_pipe_util_pct",
          "stall_1", "stall_1_pct", "stall_2", "stall_2_pct", "stall_3", "stall_3_pct"]
TOTAL_FIELDS = ["impl", "N", "batch", "batch_mode", "cache_control", "kernel_count", "total_time_us",
                "total_dram_bytes", "effective_memory_passes", "dram_copy_traffic_factor", "calibrated_memory_passes"]


@dataclass
class Kernel:
    identity: str
    name: str
    grid: str | None
    block: str | None
    metrics: dict[str, tuple[str, str]] = field(default_factory=dict)


def parse_raw(path: Path) -> list[Kernel]:
    """Accept long (metric rows) and wide (metric columns + units row) raw CSVs.

    Profiler banners, repeated headers, quoted commas, and rule/instance rows
    are handled without confusing sections or replay passes with kernel calls.
    """
    kernels = {}
    header = None
    units = {}
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for values in csv.reader(stream):
            if "ID" in values and "Kernel Name" in values:
                header = [v.strip() for v in values]
                units = {}
                continue
            if header is None or not values or values[0].startswith("=="):
                continue
            row = dict(zip(header, values))
            if "Metric Name" not in header and not row.get("ID", "").strip():
                units = row
                continue
            if not row.get("ID", "").strip() or not row.get("Kernel Name", "").strip():
                continue
            # IDs may repeat across processes/contexts; never merge their launches.
            identity = ":".join(row.get(k, "") for k in ["Process ID", "Context", "Stream", "ID"])
            kernel = kernels.setdefault(identity, Kernel(identity, row["Kernel Name"], row.get("Grid Size"), row.get("Block Size")))
            if "Metric Name" in header:
                metric = row.get("Metric Name", "").strip()
                if metric and not row.get("Instance", "").strip():
                    kernel.metrics.setdefault(metric, (row.get("Metric Value", ""), row.get("Metric Unit", "")))
            else:
                for metric in header:
                    if "__" in metric:
                        kernel.metrics[metric] = (row.get(metric, ""), units.get(metric, ""))
    if not kernels:
        raise ValueError(f"no profiled kernel launches in {path}; check NVTX filter and ncu log")
    return list(kernels.values())


def convert(value: str, unit: str, kind: str) -> float | None:
    result = number(value)
    if result is None:
        return None
    unit = unit.strip().lower().replace("μ", "u").replace("µ", "u")
    if kind == "duration_us":
        factors = {"nsecond": .001, "ns": .001, "usecond": 1, "us": 1, "msecond": 1000,
                   "ms": 1000, "second": 1e6, "s": 1e6}
        if unit not in factors:
            warnings.warn(f"unknown duration unit {unit!r}; emitting NA", stacklevel=2)
            return None
        return result * factors[unit]
    if kind.endswith("bytes"):
        factors = {"byte": 1, "bytes": 1, "b": 1, "kbyte": 1e3, "mbyte": 1e6,
                   "gbyte": 1e9, "kib": 1024, "mib": 1024**2, "gib": 1024**3}
        if unit not in factors:
            warnings.warn(f"unknown byte unit {unit!r}; emitting NA", stacklevel=2)
            return None
        return result * factors[unit]
    if kind.endswith("_pct") and unit in ("ratio", "fraction"):
        return result * 100
    return result


def metric(kernel: Kernel, field_name: str) -> float | None:
    for name in METRICS[field_name]:
        if name in kernel.metrics:
            value, unit = kernel.metrics[name]
            result = convert(value, unit, field_name)
            if result is not None:
                return result
    if field_name == "lts_bytes" and "lts__t_sectors.sum" in kernel.metrics:
        result = number(kernel.metrics["lts__t_sectors.sum"][0])
        if result is not None:
            warnings.warn("lts__t_bytes.sum missing; using 32 * lts__t_sectors.sum", stacklevel=2)
            return result * 32
    warnings.warn(f"{kernel.name}: missing/invalid {METRICS[field_name][0]}; emitting NA", stacklevel=2)
    return None


def complete_sum(values) -> float | None:
    values = list(values)
    return sum(values) if all(v is not None for v in values) else None


def summarize(kernels: list[Kernel], config: dict, limits: dict) -> tuple[list[dict], dict]:
    rows = []
    hbm, l2 = positive(limits.get("hbm_copy_GBs")), positive(limits.get("l2_copy_GBs_plateau"))
    if hbm is None or l2 is None:
        warnings.warn("measured HBM/L2 copy limit missing or nonpositive; affected percentages are NA", stacklevel=2)
    for kernel in kernels:
        short_name = re.sub(r"^(?:void|__global__)\s+", "", kernel.name).split("(", 1)[0]
        row = {**config, "kernel_id": kernel.identity, "kernel": short_name,
               **{key: metric(kernel, key) for key in METRICS}}
        for field_name, metadata, name in [("grid", kernel.grid, "launch__grid_size"), ("block", kernel.block, "launch__block_size")]:
            fallback = kernel.metrics.get(name, (None, ""))[0]
            missing = {"", "na", "n/a", "nan", "none", "not supported"}
            valid_metadata = metadata if str(metadata).strip().lower() not in missing else None
            row[field_name] = valid_metadata or fallback
            if str(row[field_name]).strip().lower() in missing:
                warnings.warn(f"{kernel.name}: missing {field_name}; emitting NA", stacklevel=2)
                row[field_name] = None
        row["smem_bytes"] = complete_sum([row["static_smem_bytes"], row["dynamic_smem_bytes"]])
        dram = complete_sum([row["dram_read_bytes"], row["dram_write_bytes"]])
        duration = positive(row["duration_us"])
        row["dram_GBs"] = dram / (duration * 1000) if dram is not None and duration else None
        row["l2_GBs"] = row["lts_bytes"] / (duration * 1000) if row["lts_bytes"] is not None and duration else None
        row["pct_measured_hbm_copy"] = row["dram_GBs"] / hbm * 100 if row["dram_GBs"] is not None and hbm else None
        row["pct_measured_l2_copy"] = row["l2_GBs"] / l2 * 100 if row["l2_GBs"] is not None and l2 else None
        stalls = []
        for name, (value, unit) in kernel.metrics.items():
            if re.fullmatch(r"smsp__warp_issue_stalled_.+_per_warp_active\.pct", name):
                value = convert(value, unit, "stall_pct")
                if value is not None:
                    stalls.append((name.removeprefix("smsp__warp_issue_stalled_").removesuffix("_per_warp_active.pct"), value))
        stalls.sort(key=lambda pair: (-pair[1], pair[0]))
        if not stalls:
            warnings.warn(f"{kernel.name}: missing WarpStateStats stall percentages; emitting NA", stacklevel=2)
        for index in range(3):
            row[f"stall_{index+1}"], row[f"stall_{index+1}_pct"] = stalls[index] if index < len(stalls) else (None, None)
        rows.append(row)
    total_time = complete_sum(r["duration_us"] for r in rows)
    total_dram = complete_sum(complete_sum([r["dram_read_bytes"], r["dram_write_bytes"]]) for r in rows)
    for row in rows:
        row["pct_config_time"] = row["duration_us"] / total_time * 100 if positive(total_time) and row["duration_us"] is not None else None
    n, batch = int(config.get("N", 0)), int(config.get("batch", 0))
    total = {**config, "kernel_count": len(rows), "total_time_us": total_time, "total_dram_bytes": total_dram,
             "effective_memory_passes": total_dram / (32 * n * batch) if n > 0 and batch > 0 and total_dram is not None else None}
    return rows, total


def select_metrics(query: str) -> list[str]:
    available = set(re.findall(r"\b[a-zA-Z][a-zA-Z0-9_]*__[a-zA-Z0-9_.]+", query))
    requested = [name for names in METRICS.values() for name in names] + EXTRA_METRICS
    selected = []
    for name in requested:
        if name in available:
            selected.append(name)
        else:
            warnings.warn(f"ncu query does not list {name}; summary will use NA if full set omits it", stacklevel=2)
    selected.extend(sorted(n for n in available if re.fullmatch(r"smsp__warp_issue_stalled_.+_per_warp_active\.pct", n)))
    return sorted(set(selected))


def copy_calibration(profiles: list[tuple[dict, list[dict], dict]]) -> tuple[list[dict], float | None]:
    """Audit DRAM traffic inflation against the same GPU's known copy payload.

    The requested raw DRAM/payload ratio remains available. Its calibrated
    counterpart divides by the HBM-sized, cache-all copy's observed factor.
    """
    output = []
    hbm_factor = None
    for entry, rows, total in profiles:
        if entry["impl"] != "bwcopy":
            continue
        match = re.fullmatch(r"WS(\d+)", entry["batch_mode"])
        if not match:
            warnings.warn(f"cannot infer bandwidth copy working set: {entry['batch_mode']}", stacklevel=2)
            continue
        mib = int(match[1])
        ideal = mib * 1024**2  # source+destination bytes = ideal read+write traffic
        dram = total["total_dram_bytes"]
        lts = complete_sum(row["lts_bytes"] for row in rows)
        factor = dram / ideal if dram is not None and ideal > 0 else None
        output.append({"working_set_MiB": mib, "cache_control": entry["cache_control"],
                       "ideal_copy_bytes": ideal, "dram_bytes": dram, "lts_bytes": lts,
                       "dram_traffic_factor": factor, "lts_traffic_factor": lts / ideal if lts is not None and ideal > 0 else None})
        if mib == 4096 and entry["cache_control"] == "all":
            hbm_factor = positive(factor)
    return output, hbm_factor


def retain_reports(root: Path, max_bytes: int = 100_000_000, spill: Path | None = None) -> dict:
    reports = sorted((root / "ncu").glob("*.ncu-rep"))
    total_bytes = sum(p.stat().st_size for p in reports)
    locations = {}
    if total_bytes > max_bytes:
        spill = spill or Path(tempfile.mkdtemp(prefix=f"t1-ncu-{root.name}-"))
        spill.mkdir(parents=True, exist_ok=True)
        for path in reports:
            if re.search(r"_N(?:1048576|16777216)_b1_", path.name):
                continue
            target = spill / path.name
            if target.exists():
                raise FileExistsError(target)
            shutil.move(str(path), target)
            locations[str(path)] = str(target.resolve())
        print(f"Large ncu reports moved to {spill.resolve()}; every raw CSV remains under results/{root.name}/ncu")
    result = {"original_total_bytes": total_bytes, "spill_locations": locations}
    with (root / "ncu/report_locations.json").open("x", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    return result


def run(root: Path) -> None:
    limits_path = root / "bandwidth/limits.json"
    if limits_path.exists():
        limits = json.loads(limits_path.read_text(encoding="utf-8"))
    else:
        warnings.warn(f"{limits_path} absent; bandwidth percentages will be NA", stacklevel=2)
        limits = {}
    totals = []
    mismatch = False
    profiles = []
    for entry in read_csv(root / "ncu/index.csv"):
        if entry["status"] != "ok":
            continue
        raw_path = root / "ncu" / entry["raw_csv"]
        config = {key: entry[key] for key in ["impl", "N", "batch", "batch_mode", "cache_control"]}
        rows, total = summarize(parse_raw(raw_path), config, limits)
        profiles.append((entry, rows, total))
    calibration, traffic_factor = copy_calibration(profiles)
    if traffic_factor is None:
        warnings.warn("HBM copy calibration unavailable; calibrated memory passes are NA (raw traffic ratios remain uncalibrated)", stacklevel=2)
    if calibration:
        write_csv(root / "ncu/summary/copy_calibration.csv", calibration, list(calibration[0]))
    for entry, rows, total in profiles:
        raw_path = root / "ncu" / entry["raw_csv"]
        is_fft = int(entry["N"]) > 0
        total["dram_copy_traffic_factor"] = traffic_factor if is_fft else None
        raw_passes = total["effective_memory_passes"]
        total["calibrated_memory_passes"] = raw_passes / traffic_factor if is_fft and raw_passes is not None and traffic_factor else None
        stem = raw_path.stem
        write_csv(root / "ncu/summary" / f"{stem}.csv", rows, FIELDS)
        text = "# Per-kernel profile\n\n" + md_table(rows, FIELDS)
        text += "\nConfig totals (raw traffic ratio = total DRAM bytes / (2 × 16 × N × batch); calibrated passes divide by the HBM copy traffic factor):\n\n" + md_table([total], TOTAL_FIELDS)
        text += "\nPercentages use measured copy limits. NCU replay durations are distinct from unprofiled sweep times.\n"
        if entry["impl"] == "vkfft":
            manifest = root / "vkfft_kernels" / f"N{entry['N']}_b{entry['batch']}" / "manifest.json"
            if manifest.exists():
                expected = json.loads(manifest.read_text(encoding="utf-8"))["kernel_count"]
                text += f"\nExported kernel count: {expected}; captured launch count: {len(rows)}.\n"
                if expected != len(rows):
                    warnings.warn(f"VkFFT export/ncu launch count mismatch for {stem}: {expected} != {len(rows)}", stacklevel=2)
                    mismatch = True
            else:
                warnings.warn(f"VkFFT manifest missing for {stem}; count comparison unverified", stacklevel=2)
        with (root / "ncu/summary" / f"{stem}.md").open("x", encoding="utf-8") as stream:
            stream.write(text)
        totals.append(total)
    if not totals:
        raise ValueError("ncu index contains no successfully captured/exported profiles")
    write_csv(root / "ncu/summary/config_totals.csv", totals, TOTAL_FIELDS)
    if mismatch:
        raise ValueError("VkFFT exported source count differs from captured ncu launch count; see per-config tables")


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path)
    parser.add_argument("--query-file", type=Path, action="append")
    parser.add_argument("--metrics-out", type=Path)
    parser.add_argument("--retain-reports", action="store_true")
    args = parser.parse_args(argv)
    if args.query_file:
        if not args.metrics_out:
            parser.error("--query-file requires --metrics-out")
        metrics = select_metrics("\n".join(p.read_text(encoding="utf-8") for p in args.query_file))
        with args.metrics_out.open("x", encoding="utf-8") as stream:
            stream.write(",".join(metrics) + "\n")
    elif args.results:
        retain_reports(args.results) if args.retain_reports else run(args.results)
    else:
        parser.error("provide --results or --query-file")


if __name__ == "__main__":
    main()
