"""Small, strict CSV helpers. NA is never silently converted to zero."""
from __future__ import annotations

import csv
import math
from pathlib import Path
from typing import Iterable


def number(value) -> float | None:
    if value is None:
        return None
    try:
        result = float(str(value).strip().replace(",", ""))
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def positive(value) -> float | None:
    result = number(value)
    return result if result is not None and result > 0 else None


def read_csv(path: Path) -> list[dict[str, str]]:
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames:
            raise ValueError(f"empty CSV: {path}")
        return list(reader)


def write_csv(path: Path, rows: Iterable[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: "NA" if row.get(key) is None else row.get(key) for key in fields})


def md_table(rows: Iterable[dict], fields: list[str]) -> str:
    def cell(value):
        if value is None:
            return "NA"
        if isinstance(value, float):
            return f"{value:.6g}"
        return str(value).replace("|", r"\|").replace("\n", " ")

    lines = ["| " + " | ".join(fields) + " |", "| " + " | ".join("---" for _ in fields) + " |"]
    lines.extend("| " + " | ".join(cell(row.get(key)) for key in fields) + " |" for row in rows)
    return "\n".join(lines) + "\n"
