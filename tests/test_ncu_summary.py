import json
import shutil
import warnings

import pytest

from io_utils import read_csv, write_csv
from ncu_summary import (convert, copy_calibration, main, parse_raw, retain_reports, run, select_metrics, summarize)

CONFIG = {"impl": "legacy", "N": "65536", "batch": "1", "batch_mode": "b1", "cache_control": "all"}
LIMITS = {"hbm_copy_GBs": 1000, "l2_copy_GBs_plateau": 4000}


def test_long_csv_keeps_repeated_launches_and_converts_units(fixtures):
    kernels = parse_raw(fixtures / "ncu_raw.csv")
    assert len(kernels) == 2
    assert kernels[0].identity != kernels[1].identity
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        rows, total = summarize(kernels, CONFIG, LIMITS)
    assert rows[0]["duration_us"] == 10
    assert rows[1]["duration_us"] == 5
    assert rows[0]["smem_bytes"] == 4096
    assert rows[0]["dram_GBs"] == pytest.approx(209.7152)
    assert rows[0]["pct_measured_hbm_copy"] == pytest.approx(20.97152)
    assert rows[0]["l2_GBs"] == pytest.approx(314.5728)
    assert rows[0]["pct_measured_l2_copy"] == pytest.approx(7.86432)
    assert rows[0]["pct_config_time"] == pytest.approx(100 * 2 / 3)
    assert rows[0]["stall_1"] == "long_scoreboard"
    assert rows[0]["stall_1_pct"] == 70
    assert rows[0]["grid"] == "(4, 1, 1)"
    assert total["total_time_us"] == 15
    assert total["total_dram_bytes"] == 2621440
    assert total["effective_memory_passes"] == 1.25


def test_missing_metric_is_na_with_warning_and_never_zero(fixtures, tmp_path):
    with pytest.warns(UserWarning) as caught:
        rows, total = summarize(parse_raw(fixtures / "ncu_missing.csv"), CONFIG, LIMITS)
    assert any("dram__bytes_read.sum" in str(w.message) for w in caught)
    assert rows[0]["dram_read_bytes"] is None
    assert rows[0]["dram_GBs"] is None
    assert rows[0]["pct_measured_hbm_copy"] is None
    assert rows[0]["lts_bytes"] is None
    assert total["total_dram_bytes"] is None
    target = tmp_path / "missing.csv"
    write_csv(target, rows, ["dram_read_bytes", "dram_GBs", "lts_bytes"])
    assert read_csv(target)[0]["dram_GBs"] == "NA"


def test_wide_units_row_and_quoted_name(fixtures):
    kernels = parse_raw(fixtures / "ncu_wide.csv")
    assert len(kernels) == 1
    assert kernels[0].metrics["gpu__time_duration.sum"] == ("1,000", "nsecond")
    assert "<double, 4>" in kernels[0].name


@pytest.mark.parametrize("value,unit,kind,expected", [
    ("1,000", "nsecond", "duration_us", 1), (".5", "msecond", "duration_us", 500),
    ("2", "Kbyte", "dram_read_bytes", 2000), (".25", "ratio", "occupancy_pct", 25),
    ("n/a", "byte", "lts_bytes", None), ("nan", "%", "occupancy_pct", None),
])
def test_units(value, unit, kind, expected):
    assert convert(value, unit, kind) == expected


def test_unknown_units_warn_instead_of_guessing():
    with pytest.warns(UserWarning, match="duration unit"):
        assert convert("10", "cycles", "duration_us") is None


def test_sector_fallback_and_missing_limit(fixtures):
    kernel = parse_raw(fixtures / "ncu_raw.csv")[0]
    del kernel.metrics["lts__t_bytes.sum"]
    kernel.metrics["lts__t_sectors.sum"] = ("100", "sector")
    with pytest.warns(UserWarning):
        rows, _ = summarize([kernel], CONFIG, {})
    assert rows[0]["lts_bytes"] == 3200
    assert rows[0]["pct_measured_hbm_copy"] is None


def test_available_metric_selection_filters_unknowns():
    query = "gpu__time_duration.sum nsecond\ndram__bytes_read.sum byte\nsmsp__warp_issue_stalled_barrier_per_warp_active.pct %"
    with pytest.warns(UserWarning):
        selected = select_metrics(query)
    assert set(selected) == {"gpu__time_duration.sum", "dram__bytes_read.sum", "smsp__warp_issue_stalled_barrier_per_warp_active.pct"}


def test_empty_capture_fails_loudly(tmp_path):
    path = tmp_path / "empty.csv"
    path.write_text("==PROF== No kernels were profiled\n", encoding="utf-8")
    with pytest.raises(ValueError, match="NVTX filter"):
        parse_raw(path)


def prepare_run(tmp_path, fixtures, impl="legacy"):
    (tmp_path / "bandwidth").mkdir()
    (tmp_path / "bandwidth/limits.json").write_text(json.dumps(LIMITS), encoding="utf-8")
    (tmp_path / "ncu").mkdir()
    shutil.copyfile(fixtures / "ncu_raw.csv", tmp_path / "ncu/raw.csv")
    entry = {**CONFIG, "impl": impl, "raw_csv": "raw.csv", "status": "ok"}
    write_csv(tmp_path / "ncu/index.csv", [entry], list(entry))


def test_cli_writes_csv_markdown_and_totals(fixtures, tmp_path):
    prepare_run(tmp_path, fixtures)
    with pytest.warns(UserWarning, match="HBM copy calibration"):
        main(["--results", str(tmp_path)])
    rows = read_csv(tmp_path / "ncu/summary/raw.csv")
    assert len(rows) == 2
    assert (tmp_path / "ncu/summary/raw.md").exists()
    assert read_csv(tmp_path / "ncu/summary/config_totals.csv")[0]["kernel_count"] == "2"


def test_copy_traffic_calibration_is_measured_not_assumed():
    ideal = 4096 * 1024**2
    entry = {"impl": "bwcopy", "batch_mode": "WS4096", "cache_control": "all"}
    rows = [{"lts_bytes": ideal}]
    table, factor = copy_calibration([(entry, rows, {"total_dram_bytes": ideal * 1.25})])
    assert factor == 1.25
    assert table[0]["lts_traffic_factor"] == 1
    assert table[0]["dram_traffic_factor"] == 1.25


def test_export_launch_count_mismatch_is_actionable(fixtures, tmp_path):
    prepare_run(tmp_path, fixtures, impl="vkfft")
    directory = tmp_path / "vkfft_kernels/N65536_b1"
    directory.mkdir(parents=True)
    (directory / "manifest.json").write_text('{"kernel_count":3}', encoding="utf-8")
    with pytest.warns(UserWarning) as caught, pytest.raises(ValueError, match="source count"):
        run(tmp_path)
    assert any("count mismatch" in str(item.message) for item in caught)
    assert (tmp_path / "ncu/summary/raw.md").exists()


def test_report_retention_preserves_only_requested_single_batch_reports(tmp_path):
    directory = tmp_path / "ncu"
    directory.mkdir()
    keep = directory / "cufft_N1048576_b1_b1_cache_all.ncu-rep"
    move = directory / "legacy_N65536_b512_t25_cache_all.ncu-rep"
    for path in [keep, move]:
        path.write_bytes(b"synthetic report content")
    result = retain_reports(tmp_path, max_bytes=1, spill=tmp_path / "spill")
    assert keep.exists()
    assert not move.exists()
    assert len(result["spill_locations"]) == 1
    assert (tmp_path / "spill" / move.name).exists()


def test_query_cli(fixtures, tmp_path):
    query = tmp_path / "query.txt"
    query.write_text("gpu__time_duration.sum", encoding="utf-8")
    out = tmp_path / "metrics.txt"
    with pytest.warns(UserWarning):
        main(["--query-file", str(query), "--metrics-out", str(out)])
    assert out.read_text(encoding="utf-8").strip() == "gpu__time_duration.sum"
