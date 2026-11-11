import csv
from pathlib import Path
import shutil

import pytest

from make_report import generate_report


FIXTURE = Path(__file__).parent / "fixtures/report"
TAG = "smoke_l4_20261111"


def test_missing_metadata_and_non_a100_banner():
    report = generate_report(FIXTURE, TAG)
    assert "smoke test, not official numbers" in report
    assert "n/a[^missing-" in report
    assert f"results/{TAG}/env.txt: missing gpu_name" in report


def test_captured_environment(tmp_path):
    run = tmp_path / "a100"
    run.mkdir()
    (run / "env.txt").write_text(
        "2026-11-11T19:30:00+08:00\n"
        "    Product Name : NVIDIA A100-SXM4-40GB\n"
        "Driver Version : 580.82.07\n"
        "    Clocks\n        Graphics : 1410 MHz\n        SM : 1410 MHz\n"
        "        Memory : 1215 MHz\n    Applications Clocks\n        Memory : 9999 MHz\n"
        "Cuda compilation tools, release 13.0, V13.0.88\n"
        "NVIDIA Nsight Compute Command Line Profiler\nVersion 2025.3.1.0\n"
    )
    (run / "ncu").mkdir()
    (run / "ncu/commands.txt").write_text("ncu --cache-control all --clock-control none --set full\n")
    report = generate_report(tmp_path, "a100")
    assert "smoke test, not official numbers" not in report
    for value in ("580.82.07", "13.0", "2025.3.1.0", "1410 MHz", "1215 MHz", "+08:00"):
        assert value in report
    assert "9999 MHz" not in report
    assert "| ncu cache control | all |" in report
    assert "| ncu clock control | none |" in report


def test_measured_limits_and_floors():
    report = generate_report(FIXTURE, TAG)
    assert "| HBM read (GB/s) | 259.81 |" in report
    assert "| L2 read plateau (GB/s) | 1486.92 |" in report
    assert "| 65536 | 1 | b1 | hot | inplace | 3.4304 | ok |" in report
    assert "theoretical_dram" not in report


def test_missing_limit_file(tmp_path):
    report = generate_report(tmp_path, "empty")
    assert "| HBM read (GB/s) | n/a[^missing-" in report
    assert "results/empty/bandwidth/limits.json: missing hbm_read_GBs" in report
    assert "results/empty/bandwidth/pass_floor.csv: missing pass-floor rows" in report


def copy_run(tmp_path, name="current"):
    target = tmp_path / name
    shutil.copytree(FIXTURE / TAG, target)
    return target


def read_rows(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def write_rows(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def test_sweep_uses_measured_times_and_matching_floors():
    report = generate_report(FIXTURE, TAG, impls=("legacy", "vkfft"))
    assert "| 65536 | 1 | b1 | legacy | hot | 63.1296 | 0.727494 | 18.403 | ok |" in report
    assert "| 65536 | 1 | b1 | legacy | cold | 73.728 | 0.736111 | 4 | ok |" in report
    assert "| 16777216 | 1 | b1 | legacy | hot | n/a" in report
    assert "unsupported" in report
    assert "impl_detail" not in report


@pytest.mark.parametrize("with_detail", [False, True])
def test_fft2_optional_impl_detail(tmp_path, with_detail):
    target = copy_run(tmp_path)
    rows = read_rows(target / "sweep/raw.csv")
    fft2 = [dict(row, impl="fft2") for row in rows if row["impl"] == "legacy" and row["N"] == "65536"]
    if with_detail:
        for row in rows:
            row["impl_detail"] = ""
        for row in fft2:
            row["impl_detail"] = "padding"
        fft2 += [dict(row, impl_detail="radix8") for row in fft2]
    write_rows(target / "sweep/raw.csv", rows + fft2)
    report = generate_report(tmp_path, "current", impls=("fft2",))
    if with_detail:
        assert "| fft2 | padding | hot | 63.1296 | 0.727494 | 18.403 | ok |" in report
        assert "| fft2 | radix8 | cold | 73.728 | 0.736111 | 4 | ok |" in report
    else:
        assert "impl_detail" not in report
        assert "| fft2 | hot | 63.1296 | 0.727494 | 18.403 | ok |" in report


def test_wrong_results_do_not_get_derived_metrics(tmp_path):
    target = copy_run(tmp_path)
    rows = read_rows(target / "sweep/raw.csv")
    rows[0]["status"] = "wrong"
    write_rows(target / "sweep/raw.csv", rows)
    report = generate_report(tmp_path, "current")
    assert "| legacy | hot | 63.1296 | n/a" in report
    assert "status=wrong; derived metrics require ok" in report


def test_missing_floor_is_not_replaced_by_derived_estimate(tmp_path):
    target = copy_run(tmp_path)
    (target / "bandwidth/pass_floor.csv").unlink()
    report = generate_report(tmp_path, "current")
    assert "| legacy | hot | 63.1296 | 0.727494 | n/a" in report
    assert "missing inplace time_ms_median for ('65536', '1', 'b1', 'hot')" in report


def test_duplicate_join_keys_are_rejected(tmp_path):
    target = copy_run(tmp_path)
    rows = read_rows(target / "sweep/raw.csv")
    write_rows(target / "sweep/raw.csv", rows + [rows[0]])
    with pytest.raises(ValueError, match="duplicate join key"):
        generate_report(tmp_path, "current")
