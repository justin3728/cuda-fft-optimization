"""Join measured FFT times with their measured, in-place one-pass floors."""
from __future__ import annotations

import argparse
from pathlib import Path
import warnings

from io_utils import positive, read_csv, write_csv

ADDED = ["gflops", "bytes_one_pass", "eff_bw_one_pass_GBs", "t_pass_ms", "pass_equiv", "pct_of_cufft"]


def key(row: dict) -> tuple[int, int, str, str]:
    return int(row["N"]), int(row["batch"]), row["batch_mode"], row["timing_mode"]


def derive(raw: list[dict], floors: list[dict]) -> list[dict]:
    floor_times = {}
    for row in floors:
        if row["copy_kind"] != "inplace" or row["status"] != "ok":
            continue
        index = key(row)
        if index in floor_times:
            raise ValueError(f"duplicate in-place pass floor: {index}")
        floor_times[index] = positive(row["time_ms_median"])
    cufft_times = {}
    seen = set()
    for row in raw:
        index = (row["impl"], *key(row))
        if index in seen:
            raise ValueError(f"duplicate sweep row: {index}")
        seen.add(index)
        if row["impl"] == "cufft" and row["status"] == "ok":
            cufft_times[key(row)] = positive(row["time_ms_median"])
    output = []
    for row in raw:
        item = {**row, **dict.fromkeys(ADDED)}
        n, batch, _, _ = key(row)
        if n < 2 or n & (n - 1) or batch < 1:
            raise ValueError(f"invalid dimensions in sweep: N={n}, batch={batch}")
        byte_count = 32 * n * batch
        item["bytes_one_pass"] = byte_count
        if row["status"] == "ok":
            time = positive(row["time_ms_median"])
            if time is None:
                warnings.warn(f"invalid median time for {row['impl']} {key(row)}; derived metrics are NA", stacklevel=2)
            else:
                item["gflops"] = 5 * n * (n.bit_length() - 1) * batch / (time * 1e6)
                item["eff_bw_one_pass_GBs"] = byte_count / (time * 1e6)
                floor = floor_times.get(key(row))
                if floor is None:
                    warnings.warn(f"missing valid in-place pass floor for {key(row)}", stacklevel=2)
                else:
                    item["t_pass_ms"] = floor
                    item["pass_equiv"] = time / floor
                cufft = cufft_times.get(key(row))
                if cufft is not None:
                    item["pct_of_cufft"] = cufft / time * 100
                else:
                    warnings.warn(f"missing valid cuFFT baseline for {key(row)}", stacklevel=2)
        output.append(item)
    return output


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", required=True, type=Path)
    parser.add_argument("--pass-floor", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    raw = read_csv(args.raw)
    if not raw:
        raise ValueError("sweep contains no rows")
    write_csv(args.output, derive(raw, read_csv(args.pass_floor)), list(raw[0]) + ADDED)


if __name__ == "__main__":
    main()
