import csv
from pathlib import Path
import shutil

import pytest

from make_report import Missing, Record, Run, gap_values, generate_report, kernel_metrics


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


def test_none_is_a_measured_cache_policy(tmp_path):
    target = tmp_path / "policies/ncu"
    write_rows(target / "index.csv", [dict(cache_control="none", clock_control="none")])
    report = generate_report(tmp_path, "policies")
    assert "| ncu cache control | none |" in report
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


def test_old_markdown_profiles_keep_repeated_kernel_launches():
    report = generate_report(FIXTURE, TAG)
    assert report.count("| fft_block_1024_specialized |") == 4
    assert report.count("| regular_fft_factor&lt;") == 4
    assert report.count("| VkFFT_main |") == 4
    assert "**L2-resident:** DRAM bytes undercount traffic" in report
    assert "| 68.928 | 1.92402e+07 | 12544 |" in report
    assert "| tex_throttle | 59.02 | barrier | 13.46 |" in report


def test_kernel_arithmetic_and_missing_counters(tmp_path):
    # Deliberately small CPU arithmetic/schema fixture, not GPU evidence.
    target = tmp_path / "arithmetic"
    write_rows(target / "ncu/summary/copy_calibration.csv", [dict(
        working_set_MiB=4096, cache_control="all", dram_traffic_factor=2)])
    (target / "bandwidth").mkdir()
    (target / "bandwidth/limits.json").write_text(
        '{"hbm_read_GBs":2,"hbm_write_GBs":4,"l2_read_GBs_plateau":8}')
    run = Run(tmp_path, "arithmetic")
    row = Record(dict(N=128, batch=1, duration_us=10, dram_read_bytes=2000,
                      dram_write_bytes=4000, lts_bytes=16000), "arithmetic CSV row")
    metrics = kernel_metrics(run, row)
    assert metrics == {"read_ratio": 0.48828125, "write_ratio": 0.9765625, "mixed": 20, "l2": 20}
    row.data["dram_write_bytes"] = "NA"
    row.data["pct_l2_limit"] = "NA"
    metrics = kernel_metrics(run, row)
    assert isinstance(metrics["write_ratio"], Missing)
    assert isinstance(metrics["mixed"], Missing)
    assert isinstance(metrics["l2"], Missing)  # Do not replace explicit missing measurements.
    row.data["dram_write_bytes"] = 0
    assert kernel_metrics(run, row)["write_ratio"] == 0


def test_modern_csv_preferred_over_sibling_markdown(tmp_path):
    target = copy_run(tmp_path)
    row = dict(impl="fft2", N=65536, batch=1, batch_mode="b1", cache_control="all", impl_detail="padding",
               kernel_id="1:1:1:0", kernel="pass_one", duration_us="12", dram_read_bytes="0", dram_write_bytes="0",
               lts_bytes="2097152", pct_mixed_hbm_limit="NA", pct_l2_limit="17.5", working_set_fits_l2="true",
               achieved_occupancy_pct="42", shared_bank_conflicts_ld="0", shared_bank_conflicts_st="0",
               stall_1="barrier", stall_1_pct="25", stall_2="long_scoreboard", stall_2_pct="20")
    write_rows(target / "ncu/summary/fft2_profile.csv", [row])
    (target / "ncu/summary/fft2_profile.md").write_text("| kernel |\n| --- |\n| must_not_appear |\n")
    report = generate_report(tmp_path, "current", impls=("fft2",))
    assert "must_not_appear" not in report
    assert "impl_detail=padding" in report
    assert report.count("| pass_one |") == 1
    assert "| n/a[^missing-" in report
    assert "missing pct_mixed_hbm_limit" in report
    assert "| 17.5 | 42 | 0 | 0 | barrier | 25 | long_scoreboard | 20 |" in report


def test_missing_calibration_does_not_use_stored_factor(tmp_path):
    target = copy_run(tmp_path)
    (target / "ncu/copy_calibration.csv").unlink()
    report = generate_report(tmp_path, "current")
    assert "missing dram_traffic_factor for working_set_MiB=4096" in report
    assert "| 68.928 | 1.92402e+07 | 12544 | n/a[^missing-" in report


def test_gap_units_percentage_policy_and_missing_passes(tmp_path):
    # CPU-only arithmetic fixture: 10 µs − 3 passes × 2 µs = 4 µs (40%).
    target = tmp_path / "arithmetic"
    write_rows(target / "bandwidth/pass_floor.csv", [dict(
        N=128, batch=1, batch_mode="b1", timing_mode="hot", copy_kind="inplace", status="ok", time_ms_median=.002)])
    write_rows(target / "ncu/copy_calibration.csv", [dict(
        working_set_MiB=4096, cache_control="all", dram_traffic_factor=2)])
    total = dict(impl="fft2", N=128, batch=1, batch_mode="b1", cache_control="none", calibrated_memory_passes=3)
    write_rows(target / "ncu/config_totals.csv", [total])
    row = Record(dict(impl="fft2", N=128, batch=1, batch_mode="b1", timing_mode="hot",
                      status="ok", time_ms_median=.010), "CPU arithmetic")
    assert gap_values(Run(tmp_path, "arithmetic"), row) == (3, 4, 40)
    total["cache_control"] = "all"
    write_rows(target / "ncu/config_totals.csv", [total])
    assert all(isinstance(value, Missing) for value in gap_values(Run(tmp_path, "arithmetic"), row))


def test_extrapolated_totals_do_not_supply_gap(tmp_path):
    target = copy_run(tmp_path)
    rows = read_rows(target / "ncu/config_totals.csv")
    for row in rows:
        row["totals_extrapolated"] = "true"
    write_rows(target / "ncu/config_totals.csv", rows)
    report = generate_report(tmp_path, "current")
    assert "sampled/extrapolated totals cannot supply a measured gap" in report
    assert "| 1048576 | 1 | b1 | legacy | hot | 604.365 | 1.16181 | 21.6587 | ok | n/a" in report


def test_before_after_partial_overlap(tmp_path):
    current = copy_run(tmp_path, "current")
    baseline = copy_run(tmp_path, "before")
    old = [row for row in read_rows(baseline / "sweep/raw.csv") if row["N"] != "16777216"]
    new = [row for row in read_rows(current / "sweep/raw.csv") if row["N"] != "1048576"]
    for row in old:
        if row["impl"] == "legacy":
            row["time_ms_median"] = str(float(row["time_ms_median"]) * 2)
    write_rows(baseline / "sweep/raw.csv", old)
    write_rows(current / "sweep/raw.csv", new)
    report = generate_report(tmp_path, "current", baseline_tag="before", impls=("legacy",))
    comparison = report.split("## Before / after")[1].split("## Missing data")[0]
    assert "| 65536 | 1 | b1 | legacy | hot | 126.259 | 63.1296 | -63.1296 | -50 | ok | ok |" in comparison
    assert "| 1048576 |" not in comparison
    assert "| 16777216 |" not in comparison
    assert "### Baseline environment: before" in comparison
    assert "smoke test, not official numbers" in comparison


def test_before_after_does_not_cross_variant_keys(tmp_path):
    current = copy_run(tmp_path, "current")
    baseline = copy_run(tmp_path, "before")
    for target, variant in ((current, "padding"), (baseline, "radix8")):
        rows = [dict(row, impl="fft2", impl_detail=variant) for row in read_rows(target / "sweep/raw.csv")
                if row["impl"] == "legacy"]
        write_rows(target / "sweep/raw.csv", rows)
    report = generate_report(tmp_path, "current", baseline_tag="before", impls=("fft2",))
    assert "missing shared requested sweep configurations" in report
    assert "| -50 |" not in report


def test_missing_baseline_is_reported(tmp_path):
    copy_run(tmp_path)
    report = generate_report(tmp_path, "current", baseline_tag="absent")
    assert "results/absent/sweep/raw.csv" in report
    assert "missing shared requested sweep configurations" in report
