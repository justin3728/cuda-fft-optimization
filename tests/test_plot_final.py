import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = Path(__file__).parent / "fixtures" / "final"


def test_plot_final_outputs_and_tables(tmp_path):
    subprocess.run([sys.executable, str(ROOT / "scripts/analysis/plot_final.py"), str(FIXTURE), "--out", str(tmp_path)],
                   check=True)
    for stem in ("bandwidth_b1", "relative_cufft", "relative_vkfft", "kernels"):
        for ext in ("svg", "png"):
            assert (tmp_path / f"{stem}.{ext}").stat().st_size > 0
    text = (tmp_path / "tables.md").read_text(encoding="utf-8")
    # hot medians in us, fft2 % of cuFFT / VkFFT (legacy, cold and non-ok rows excluded)
    assert "| 2^16 | b1 | 20.0 | 10.0 | 12.5 | 50 | 62 |" in text
    assert "| 2^17 | b1 | 40.0 | 20.0 | 25.0 | 50 | 62 |" in text
    # fft2[...] variant counts as fft2; the cuFFT row with status=error is dropped
    assert "| 2^18 | b1 | 50.0 | - | - | - | - |" in text
    # per-kernel: GB/s = (16+2) MB / 50 us = 360; 36% of 1000 GB/s HBM; 60 MB / 50 us = 1200 GB/s = 60% of 2000
    assert "| cuFFT | k1 | 50.0 | 16.0 | 2.0 | 360 | 36 | 60 |" in text
    # fft2: (10+4) MB / 100 us = 140 GB/s; 100 MB / 100 us = 1000 GB/s = 50% of L2
    assert "| fft2 | pass1 | 100.0 | 10.0 | 4.0 | 140 | 14 | 50 |" in text
    assert "2^24, batch 1" not in text  # missing ncu config is skipped
