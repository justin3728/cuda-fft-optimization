import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

import pytest

from io_utils import read_csv
from test_scripts import printed_commands, shell_file

ROOT = Path(__file__).resolve().parents[1]


def test_variants_dry_run_has_one_build_and_the_expected_sweeps_and_profiles(bash, tmp_path):
    variants = tmp_path / "variants with spaces.txt"
    variants.write_text("# comment\r\nn1=0 c=0 r=0\r\nn1=1024 c=8 r=4 log2=20 oop=1", encoding="utf-8")
    tag = "variants_dry_" + uuid.uuid4().hex
    command = [bash, "scripts/run_fft2_variants.sh", "--tag", tag, "--variants", str(variants),
               "--log2", "20,24", "--batch-modes", "b1", "--profile-log2", "20", "--dry-run"]
    result = subprocess.run(command + ["--ncu"], cwd=ROOT, text=True, capture_output=True, check=True)
    commands = printed_commands(result.stdout)
    assert sum(cmd[:4] == ["make", "-B", "tools", "bench"] for cmd in commands) == 1
    assert sum("scripts/run_bwtest.sh" in cmd for cmd in commands) == 1
    sweeps = [cmd for cmd in commands if "scripts/run_sweep.sh" in cmd]
    assert len(sweeps) == 3
    assert [cmd[cmd.index("--tag") + 1] for cmd in sweeps] == [tag + ".baseline", tag + ".v001", tag + ".v002"]
    assert [cmd[cmd.index("--impls") + 1] for cmd in sweeps] == ["legacy,cufft,vkfft", "fft2", "fft2"]
    assert "FFT_BENCH=results/" + tag + "/build/fft_bench" in sweeps[2]
    assert sweeps[2][sweeps[2].index("--log2") + 1] == "20"
    assert sweeps[2][sweeps[2].index("--fft2-n1") + 1] == "1024"
    assert "--fft2-out-of-place" in sweeps[2]
    profiles = [cmd for cmd in commands if "scripts/run_ncu.sh" in cmd]
    assert len(profiles) == 3
    assert all("--skip-copy-profiles" in cmd for cmd in profiles[1:])
    assert "merge_variants.py" in result.stdout
    assert not any((ROOT / "results").glob(tag + "*"))
    without_ncu = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
    assert "scripts/run_ncu.sh" not in without_ncu.stdout
    assert "--skip-ncu" in without_ncu.stdout


@pytest.mark.parametrize("line", [
    "n1=0 c=0", "n1=0 c=0 r=0 junk=1", "n1=0 c=0 r=0 c=4", "n1=0 c=-1 r=0",
    "n1=0 c=99999999999 r=0", "n1=0 c=0 r=0 oop=2", "n1=1024 c=0 r=0 log2=16",
    "n1=0 c=0 r=0\nn1=0 c=0 r=0", "n1=0 c=0 r=0 log2=25",
])
def test_bad_variant_files_fail_before_running_any_commands(bash, tmp_path, line):
    variants = tmp_path / "bad.txt"
    variants.write_text(line + "\n", encoding="utf-8")
    result = subprocess.run([bash, "scripts/run_fft2_variants.sh", "--tag", "invalid_variants_dry",
                             "--variants", str(variants), "--log2", "16", "--dry-run"],
                            cwd=ROOT, text=True, capture_output=True)
    assert result.returncode == 2
    assert not printed_commands(result.stdout)


def test_default_candidates_fit_documented_a100_budgets_and_cover_every_size(bash):
    candidates = []
    for line in (ROOT / "scripts/fft2_variants_default.txt").read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            candidates.append(dict(field.split("=", 1) for field in line.split()))
    assert candidates[0] == {"n1": "0", "c": "0", "r": "0"}
    for exponent in range(16, 25):
        applicable = [c for c in candidates if "log2" not in c or str(exponent) in c["log2"].split(",")]
        assert len(applicable) == 7
        physical = set()
        for candidate in applicable:
            n1 = int(candidate["n1"]) or 1 << (exponent // 2)
            n2 = (1 << exponent) // n1
            assert 256 <= n1 <= 4096 and 256 <= n2 <= 4096
            lanes = []
            for field, length in [("c", n1), ("r", n2)]:
                width = int(candidate[field])
                if width == 0:
                    width = 8
                    while length * width * 16 > 163 * 1024:
                        width //= 2
                assert length * width * 16 <= 163 * 1024
                lanes.append(width)
            physical.add((n1, *lanes, int(candidate.get("oop", 0))))
        assert len(physical) == 7
    result = subprocess.run([bash, "scripts/run_fft2_variants.sh", "--tag", "default_variants_dry", "--dry-run"],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    assert sum("scripts/run_sweep.sh" in cmd for cmd in printed_commands(result.stdout)) == 56


@pytest.mark.parametrize("failing_worker", ["", ".v002"])
def test_variants_reuse_build_and_continue_after_a_worker_failure(bash, tmp_path, failing_worker):
    shutil.copytree(ROOT / "scripts", tmp_path / "scripts")
    variants = tmp_path / "variants.txt"
    variants.write_text("n1=0 c=0 r=0\nn1=256 c=4 r=4\nn1=256 c=2 r=2\n", encoding="utf-8")
    for name in ["collect_env.sh", "run_bwtest.sh", "run_analysis.sh"]:
        shell_file(tmp_path / "scripts" / name, f"echo {name} >> trace.txt")
    shell_file(tmp_path / "scripts/run_sweep.sh", '''
"$PYTHON" - "$@" <<'PY'
import csv, os, sys
from pathlib import Path
args=dict(zip(sys.argv[1::2], sys.argv[2::2]))
tag=args['--tag']
impls=args['--impls'].split(',')
if impls == ['fft2']:
    impls=['fft2[n1=%s,c=%s,r=%s]' % (args['--fft2-n1'], args['--fft2-tile-cols'], args['--fft2-tile-rows'])]
path=Path('results')/tag/'sweep/raw.csv'
path.parent.mkdir(parents=True)
with path.open('x', newline='') as stream:
    fields=['impl','N','log2N','batch','batch_mode','timing_mode','status','time_ms_median','impl_detail']
    writer=csv.DictWriter(stream,fieldnames=fields)
    writer.writeheader()
    for impl in impls:
        writer.writerow(dict(impl=impl,N=65536,log2N=16,batch=1,batch_mode='b1',timing_mode='hot',status='ok',time_ms_median=1,impl_detail='synthetic plan' if impl.startswith('fft2') else ''))
with Path('trace.txt').open('a') as stream: stream.write(tag+'\\n')
sys.exit(2 if os.environ.get('FAIL_WORKER') and tag.endswith(os.environ['FAIL_WORKER']) else 0)
PY
''')
    bins = tmp_path / "bin"
    bins.mkdir()
    shell_file(bins / "git", "exit 0")
    shell_file(bins / "make", "echo make >> trace.txt")
    env = {**os.environ, "PYTHON": Path(sys.executable).as_posix(), "FAIL_WORKER": failing_worker}
    result = subprocess.run([bash, "-c", 'export PATH="$PWD/bin:$PATH"; exec bash scripts/run_fft2_variants.sh --tag variants --variants variants.txt --log2 16 --batch-modes b1'],
                            cwd=tmp_path, text=True, capture_output=True, env=env)
    assert result.returncode == (1 if failing_worker else 0), result.stdout + result.stderr
    trace = (tmp_path / "trace.txt").read_text().splitlines()
    assert trace.count("make") == trace.count("run_bwtest.sh") == 1
    assert "variants.v003" in trace and trace[-1] == "run_analysis.sh"
    rows = read_csv(tmp_path / "results/variants/sweep/raw.csv")
    assert len(rows) == 6
    assert len({row["impl"] for row in rows}) == 6
    assert len(read_csv(tmp_path / "results/variants/variants.csv")) == 3
    assert (tmp_path / "results/variants/variants/baseline/sweep/raw.csv").exists()
    assert all((tmp_path / "results/variants" / row["path"] / "sweep/raw.csv").exists()
               for row in read_csv(tmp_path / "results/variants/variants.csv"))
    assert not (tmp_path / "results/variants.v001").exists()
