"""Combine isolated variant workers into one four-backend analysis input."""
from __future__ import annotations

import argparse
import os
from pathlib import Path

from io_utils import read_csv, write_csv


def merge(root: Path, sources: list[Path], ncu: bool = False) -> None:
    rows = []
    entries = []
    seen = set()
    for source in sources:
        for row in read_csv(source / "sweep/raw.csv"):
            row.setdefault("impl_detail", "")
            key = tuple(row[k] for k in ("impl", "N", "batch", "batch_mode", "timing_mode"))
            if key in seen:
                raise ValueError(f"duplicate variant sweep row: {key}")
            seen.add(key)
            rows.append(row)
        # Size-filtered variants may have no intersection with --profile-log2.
        if ncu and (source / "ncu/index.csv").exists():
            for entry in read_csv(source / "ncu/index.csv"):
                entry.setdefault("impl_detail", "")
                entry["raw_csv"] = os.path.relpath((source / "ncu" / entry["raw_csv"]).resolve(),
                                                   (root / "ncu").resolve())
                entries.append(entry)
    if not rows:
        raise ValueError("variant sources contain no sweep rows")
    if ncu and not entries:
        raise ValueError("variant sources contain no ncu index rows")
    write_csv(root / "sweep/raw.csv", rows, list(rows[0]))
    if ncu:
        write_csv(root / "ncu/index.csv", entries, list(entries[0]))


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path, action="append")
    parser.add_argument("--ncu", action="store_true")
    args = parser.parse_args(argv)
    merge(args.results, args.source, args.ncu)


if __name__ == "__main__":
    main()
