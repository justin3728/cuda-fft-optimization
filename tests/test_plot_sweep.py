import struct

from derive import derive
from io_utils import read_csv
from plot_sweep import plot


def test_fixture_plots_are_real_pngs(fixtures, tmp_path):
    rows = derive(read_csv(fixtures / "sweep.csv"), read_csv(fixtures / "pass_floor.csv"))
    paths = plot(rows, tmp_path / "plots", tmp_path / "summary.md")
    assert len(paths) == 6
    for path in paths:
        data = path.read_bytes()
        assert data.startswith(b"\x89PNG\r\n\x1a\n")
        width, height = struct.unpack(">II", data[16:24])
        assert width >= 1000 and height >= 600
        assert len(data) > 5000
    text = (tmp_path / "summary.md").read_text(encoding="utf-8")
    assert "unsupported" in text
    assert "pass_equiv" in text


def test_all_failed_rows_still_produce_status_summary(fixtures, tmp_path):
    rows = [{**r, "status": "error", "t_pass_ms": None, "pass_equiv": None, "pct_of_cufft": None}
            for r in read_csv(fixtures / "sweep.csv")[:1]]
    assert len(plot(rows, tmp_path / "plots", tmp_path / "summary.md")) == 3
    assert "error" in (tmp_path / "summary.md").read_text(encoding="utf-8")
