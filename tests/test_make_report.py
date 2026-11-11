from pathlib import Path

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
