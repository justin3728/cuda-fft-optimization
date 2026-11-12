from dataclasses import replace
import json
from pathlib import Path
import shutil

import matplotlib.axes
import pytest

from derive import derive
from io_utils import read_csv, write_csv
from ncu_summary import main, parse_raw, run, summarize, validate_fft2_capture
from plot_sweep import COLORS, plot

LIMITS = {"hbm_copy_GBs": 1000, "hbm_read_GBs": 1500, "hbm_write_GBs": 1200,
          "l2_copy_GBs_plateau": 4000, "l2_read_GBs_plateau": 5000, "l2_size_bytes": 48 * 1024**2}
CONFIG = {"impl": "fft2", "N": "65536", "batch": "1", "batch_mode": "b1",
          "cache_control": "all", "captured_kernels": "2", "expected_kernels": "2", "sampled": "false"}


def test_fft2_fixture_preserves_details_and_plots_each_label(fixtures, tmp_path, monkeypatch):
    rows = derive(read_csv(fixtures / "sweep_fft2.csv"), read_csv(fixtures / "pass_floor.csv"))
    variants = [row for row in rows if row["impl"].startswith("fft2")]
    assert len(variants) == 2
    assert all(row["pass_equiv"] == 2 and row["pct_of_cufft"] == 125 for row in variants)
    assert all("N1=256 N2=256" in row["impl_detail"] for row in variants)
    assert all(row["impl_detail"] == "" for row in rows[:2])
    drawn = {}
    original = matplotlib.axes.Axes.plot

    def track(self, *args, **kwargs):
        lines = original(self, *args, **kwargs)
        if kwargs.get("label", "").startswith("fft2"):
            drawn[kwargs["label"]] = (lines[0].get_color(), lines[0].get_marker(), lines[0].get_linestyle())
        return lines

    monkeypatch.setattr(matplotlib.axes.Axes, "plot", track)
    paths = plot(rows, tmp_path / "plots", tmp_path / "summary.md")
    assert len(paths) == 3 and all(path.read_bytes().startswith(b"\x89PNG") for path in paths)
    assert set(drawn) == {row["impl"] for row in variants}
    assert {style[0] for style in drawn.values()} == {COLORS["fft2"]}
    assert len(set(drawn.values())) == 2
    text = (tmp_path / "summary.md").read_text()
    assert "impl_detail" in text and "N1=256 N2=256" in text
    assert all(row["impl"] in text for row in variants)


def test_two_pass_capture_is_complete_for_any_batch_and_writes_details(fixtures, tmp_path):
    detail = read_csv(fixtures / "sweep_fft2.csv")[2]["impl_detail"]
    config = {**CONFIG, "batch": "512", "batch_mode": "t25", "impl_detail": detail}
    kernels = parse_raw(fixtures / "ncu_fft2.csv")
    rows, total = summarize(kernels, config, LIMITS)
    assert total["kernel_count"] == total["expected_kernels"] == 2
    assert total["sampled"] is False and total["extrapolation_factor"] == 1
    assert total["total_time_us"] == total["captured_time_us"] == 15
    assert all(row["impl_detail"] == detail for row in rows)
    (tmp_path / "bandwidth").mkdir()
    (tmp_path / "bandwidth/limits.json").write_text(json.dumps(LIMITS))
    (tmp_path / "ncu").mkdir()
    shutil.copyfile(fixtures / "ncu_fft2.csv", tmp_path / "ncu/raw.csv")
    entry = {**config, "raw_csv": "raw.csv", "status": "ok"}
    write_csv(tmp_path / "ncu/index.csv", [entry], list(entry))
    with pytest.warns(UserWarning, match="HBM copy calibration"):
        run(tmp_path)
    assert read_csv(tmp_path / "ncu/summary/config_totals.csv")[0]["impl_detail"] == detail
    assert read_csv(tmp_path / "ncu/summary/raw.csv")[0]["impl_detail"] == detail


@pytest.mark.parametrize("change", ["missing", "extra", "duplicate", "unrelated", "reversed"])
def test_fft2_validation_rejects_partial_or_unrelated_captures(fixtures, change):
    kernels = parse_raw(fixtures / "ncu_fft2.csv")
    if change == "missing":
        kernels = kernels[:1]
    elif change == "extra":
        kernels += [replace(kernels[0], identity="extra")]
    elif change == "duplicate":
        kernels[1] = replace(kernels[1], name=kernels[0].name)
    elif change == "unrelated":
        kernels[0] = replace(kernels[0], name="void restore_input()")
    else:
        kernels.reverse()
    with pytest.raises(ValueError, match="exactly pass1_columns then pass2_rows"):
        validate_fft2_capture(kernels)


def test_fft2_validation_accepts_templated_kernel_names(fixtures):
    # T4a made both kernels templates on KernelVariant; ncu's demangled names carry the arguments.
    kernels = parse_raw(fixtures / "ncu_fft2.csv")
    for i, name in enumerate(["pass1_columns", "pass2_rows"]):
        kernels[i] = replace(kernels[i], name=f"void fft2::(anonymous namespace)::{name}<fft2::(anonymous "
                             f"namespace)::KernelVariant<1, 2, true>>(const double2*, double2*)")
    validate_fft2_capture(kernels)


def test_fft2_rejects_extrapolation_and_accounts_for_third_oop_buffer(fixtures):
    kernels = parse_raw(fixtures / "ncu_fft2.csv")
    with pytest.raises(ValueError, match="exactly two kernels"):
        summarize(kernels, {**CONFIG, "expected_kernels": "4", "sampled": "true"}, LIMITS)
    limits = {**LIMITS, "l2_size_bytes": 32 * 65536}
    assert summarize(kernels, CONFIG, limits)[1]["working_set_fits_l2"] is True
    oop = {**CONFIG, "impl": "fft2_oop"}
    assert summarize(kernels, oop, limits)[1]["working_set_fits_l2"] is False
    main(["--check-fft2-capture", str(fixtures / "ncu_fft2.csv")])
