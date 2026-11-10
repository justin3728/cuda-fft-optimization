import pytest

from io_utils import md_table, number, positive, read_csv, write_csv


@pytest.mark.parametrize("text,expected", [("NA", None), ("inf", None), ("-nan", None), ("1,024", 1024), ("0", 0), ("-2", -2)])
def test_numeric_parsing(text, expected):
    assert number(text) == expected
    assert positive(text) == (expected if expected is not None and expected > 0 else None)


def test_csv_and_markdown_preserve_missing_and_escape_text(tmp_path):
    rows = [{"value": None, "note": 'comma, quote " and | pipe\nnewline'}]
    path = tmp_path / "data.csv"
    write_csv(path, rows, ["value", "note"])
    assert read_csv(path)[0]["value"] == "NA"
    assert read_csv(path)[0]["note"] == rows[0]["note"]
    text = md_table(rows, ["value", "note"])
    assert "\\|" in text and "NA" in text
    with pytest.raises(FileExistsError):
        write_csv(path, rows, ["value", "note"])
