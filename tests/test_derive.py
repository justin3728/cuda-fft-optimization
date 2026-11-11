import pytest

from derive import derive, main
from io_utils import read_csv


def test_derived_units_and_reference_ratios(fixtures):
    raw, floors = read_csv(fixtures / "sweep.csv"), read_csv(fixtures / "pass_floor.csv")
    rows = derive(raw, floors)
    row = rows[0]
    assert row["bytes_one_pass"] == 32 * 65536
    assert row["gflops"] == pytest.approx(5 * 65536 * 16 / (.25 * 1e6))
    assert row["eff_bw_one_pass_GBs"] == pytest.approx(32 * 65536 / (.25 * 1e6))
    assert row["pass_equiv"] == pytest.approx(2.5)
    assert row["pct_of_cufft"] == 100
    assert rows[1]["pct_of_cufft"] == 50
    assert rows[1]["t_pass_ms"] == .1  # Out-of-place floor is deliberately different.
    assert rows[7]["status"] == "unsupported"
    assert rows[7]["gflops"] is None
    assert rows[7]["pass_equiv"] is None


def test_missing_floor_bad_time_and_wrong_status(fixtures):
    raw = read_csv(fixtures / "sweep.csv")
    with pytest.warns(UserWarning, match="pass floor"):
        assert derive(raw, [])[0]["pass_equiv"] is None
    raw[0]["time_ms_median"] = "0"
    raw[1]["status"] = "wrong"
    with pytest.warns(UserWarning):
        rows = derive(raw, read_csv(fixtures / "pass_floor.csv"))
    assert rows[0]["gflops"] is None
    assert rows[1]["pct_of_cufft"] is None
    assert rows[2]["pct_of_cufft"] is None


def test_duplicate_rows_are_not_silently_joined(fixtures):
    raw, floors = read_csv(fixtures / "sweep.csv"), read_csv(fixtures / "pass_floor.csv")
    with pytest.raises(ValueError, match="duplicate sweep"):
        derive(raw + raw[:1], floors)
    with pytest.raises(ValueError, match="duplicate in-place"):
        derive(raw, floors + floors[:1])


def test_batch_modes_and_timing_modes_join_separately(fixtures):
    raw = read_csv(fixtures / "sweep.csv")[:1]
    floors = read_csv(fixtures / "pass_floor.csv")[:1]
    raw += [{**raw[0], "batch_mode": "t16"}]
    floors += [{**floors[0], "batch_mode": "t16", "time_ms_median": ".05"}]
    rows = derive(raw, floors)
    assert [row["pass_equiv"] for row in rows] == [2.5, 5]


def test_cli_writes_na_and_refuses_overwrite(fixtures, tmp_path):
    target = tmp_path / "derived.csv"
    args = ["--raw", str(fixtures / "sweep.csv"), "--pass-floor", str(fixtures / "pass_floor.csv"), "--output", str(target)]
    main(args)
    assert read_csv(target)[7]["gflops"] == "NA"
    with pytest.raises(FileExistsError):
        main(args)
