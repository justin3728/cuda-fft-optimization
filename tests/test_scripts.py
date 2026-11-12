import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from io_utils import read_csv

ROOT = Path(__file__).resolve().parents[1]


def test_full_dry_run_has_no_gpu_or_file_side_effects(bash):
    tag = "test_dry_" + uuid.uuid4().hex
    result = subprocess.run([bash, "scripts/run_t1_all.sh", "--tag", tag, "--dry-run"], cwd=ROOT,
                            text=True, capture_output=True, check=True)
    assert not (ROOT / "results" / tag).exists()
    for command in ["make -B tools bench", "nvidia-smi", "--export-vkfft", "--profile-copy-mib",
                    "--cache-control all", "--cache-control none", "derive.py", "plot_sweep.py", "ncu_summary.py"]:
        assert command in result.stdout
    assert result.stdout.count("DRY-RUN") == 7
    plans = list(re.finditer(r"NCU capture plan: impl=(\w+) N=(\d+) batch=(\d+) cache=(\w+) expected_kernels=(\S+) capture_limit=(\d+) sampled=(\w+)", result.stdout))
    assert plans
    assert sum(int(item.group(6)) for item in plans) == 334
    assert "NCU total capture upper bound: 334 kernels" in result.stdout
    assert 334 <= 400


def test_quick_skip_plan_and_bad_tag(bash):
    result = subprocess.run([bash, "scripts/run_t1_all.sh", "--tag", "quick_dry", "--dry-run", "--quick", "--skip-ncu"],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    assert "--trials 3" in result.stdout
    assert "SKIPPED" in result.stdout
    assert "--profile-copy-mib" not in result.stdout
    assert "--n 16777216 --batch 1" in result.stdout  # Quick export covers the quick sweep sizes.
    bad = subprocess.run([bash, "scripts/run_t1_all.sh", "--tag", "../outside", "--dry-run"], cwd=ROOT,
                         text=True, capture_output=True)
    assert bad.returncode != 0


def shell_file(path, text):
    path.write_text("#!/usr/bin/env bash\nset -eu\n" + text + "\n", encoding="utf-8", newline="\n")
    path.chmod(0o755)


def test_equivalent_batch_modes_share_one_vkfft_export(bash):
    result = subprocess.run([bash, "scripts/export_vkfft_kernels.sh", "--tag", "export_dry", "--dry-run",
                             "--profile-log2", "22", "--profile-batch-modes", "b8,t25"],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    assert result.stdout.count("--export-vkfft") == 1
    assert "--n 4194304 --batch 8" in result.stdout
    assert "Reusing VkFFT export" in result.stdout


def test_legacy_batched_profiles_are_bounded_to_complete_batches(bash):
    command = [bash, "scripts/run_ncu.sh", "--tag", "bounded_dry", "--dry-run", "--impls", "legacy",
               "--profile-log2", "16", "--profile-batch-modes", "t25"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
    assert "impl=legacy N=65536 batch=512 cache=all expected_kernels=2560 capture_limit=50 sampled=true" in result.stdout
    assert "--launch-count 50" in result.stdout
    rounded = subprocess.run(command + ["--ncu-max-kernels", "17"], cwd=ROOT,
                             text=True, capture_output=True, check=True)
    assert "expected_kernels=2560 capture_limit=15 sampled=true" in rounded.stdout
    assert "--launch-count 15" in rounded.stdout
    rejected = subprocess.run(command + ["--ncu-max-kernels", "4"], cwd=ROOT,
                              text=True, capture_output=True)
    assert rejected.returncode != 0
    assert "complete legacy batch" in rejected.stderr


def mock_successful_ncu(path):
    shell_file(path, '''
if [[ $* == *--version* ]]; then echo 'synthetic ncu'; exit 0; fi
if [[ $* == *--query-metrics* || $* == *--list-metrics* ]]; then echo gpu__time_duration.sum; exit 0; fi
report='' exporting=''
while (($#)); do
    case $1 in --import) report=$2; shift 2;; --export) exporting=$2; shift 2;; *) shift;; esac
done
if [[ -n $exporting ]]; then printf 'synthetic report' > "$exporting.ncu-rep"; exit 0; fi
count=1
[[ $report != *legacy_N65536* ]] || count=10
[[ $report != *cufft_N1048576* ]] || count=2
printf '"ID","Process ID","Kernel Name","Context","Stream","Block Size","Grid Size","Metric Name","Metric Unit","Metric Value"\\n'
for ((i=0; i<count; ++i)); do
    printf '"%s","1","test_kernel","1","7","(256, 1, 1)","(4, 1, 1)","gpu__time_duration.sum","nsecond","1000"\\n' "$i"
done
''')


def test_sampled_capture_records_real_count_and_full_expected_count(bash, tmp_path):
    shutil.copytree(ROOT / "scripts", tmp_path / "scripts")
    mock = tmp_path / "mock_ncu"
    mock_successful_ncu(mock)
    env = {**os.environ, "NCU": mock.as_posix(), "PYTHON": Path(sys.executable).as_posix()}
    result = subprocess.run([bash, "scripts/run_ncu.sh", "--tag", "sampled", "--impls", "legacy",
                             "--profile-log2", "16", "--profile-batch-modes", "t25", "--ncu-max-kernels", "12"],
                            cwd=tmp_path, text=True, capture_output=True, env=env)
    assert result.returncode == 0, result.stdout + result.stderr
    rows = read_csv(tmp_path / "results/sampled/ncu/index.csv")
    assert rows[0]["captured_kernels"] == "10"
    assert rows[0]["expected_kernels"] == "2560"
    assert rows[0]["sampled"] == "true"
    assert rows[0]["capture_limit"] == "10"
    assert rows[0]["kernels_per_batch"] == "5"
    assert all(row["status"] == "ok" for row in rows)


def test_library_guard_hit_is_not_misreported_as_complete_or_extrapolated(bash, tmp_path):
    shutil.copytree(ROOT / "scripts", tmp_path / "scripts")
    mock = tmp_path / "mock_ncu"
    mock_successful_ncu(mock)
    env = {**os.environ, "NCU": mock.as_posix(), "PYTHON": Path(sys.executable).as_posix()}
    result = subprocess.run([bash, "scripts/run_ncu.sh", "--tag", "guard", "--impls", "cufft",
                             "--profile-log2", "20", "--profile-batch-modes", "b1", "--ncu-library-max-kernels", "2"],
                            cwd=tmp_path, text=True, capture_output=True, env=env)
    assert result.returncode == 1
    assert "total kernel count is unknown" in result.stderr
    rows = read_csv(tmp_path / "results/guard/ncu/index.csv")
    assert rows[0]["status"] == "error"
    assert rows[0]["sampled"] == "unknown"
    assert rows[0]["expected_kernels"] == "NA"
    assert rows[0]["captured_kernels"] == "2"
    assert rows[-1]["impl"] == "bwcopy" and rows[-1]["status"] == "ok"


def test_failed_stages_do_not_stop_independent_stages(bash, tmp_path):
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    for file in ["common.sh", "run_t1_all.sh"]:
        shutil.copyfile(ROOT / "scripts" / file, scripts / file)
    for file in ["collect_env.sh", "run_bwtest.sh", "run_sweep.sh", "export_vkfft_kernels.sh", "run_ncu.sh", "run_analysis.sh"]:
        code = 2 if file == "run_bwtest.sh" else 0
        shell_file(scripts / file, f"echo reached-{file}\nexit {code}")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    shell_file(bin_dir / "git", "exit 0")
    shell_file(bin_dir / "make", "echo synthetic-build-failure\nexit 3")
    env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"]}
    # Git Bash prepends its own bin directory at process startup on Windows.
    # Set the mock path inside Bash so both Linux and Windows use the stubs.
    result = subprocess.run([bash, "-c", 'export PATH="$PWD/bin:$PATH"; exec bash scripts/run_t1_all.sh --tag stages --quick'], cwd=tmp_path,
                            text=True, capture_output=True, env=env)
    assert result.returncode == 1, result.stdout + result.stderr
    rows = read_csv(tmp_path / "results/stages/stage_status.csv")
    assert rows[0]["status"] == "FAIL(3)"
    assert next(r for r in rows if r["stage"] == "bandwidth")["status"] == "FAIL(2)"
    assert rows[-1]["stage"] == "analysis" and rows[-1]["status"] == "OK"
    assert (tmp_path / "results/stages/logs/analysis.log").exists()


def test_counter_permissions_have_actionable_error_and_nonzero_exit(bash, tmp_path):
    scripts = tmp_path / "scripts"
    shutil.copytree(ROOT / "scripts", scripts)
    mock = tmp_path / "mock_ncu"
    shell_file(mock, '''
if [[ $* == *--version* ]]; then echo 'synthetic ncu'; exit 0; fi
if [[ $* == *--query-metrics* || $* == *--list-metrics* ]]; then echo gpu__time_duration.sum; exit 0; fi
echo '==ERROR== ERR_NVGPUCTRPERM - Permission denied' >&2
exit 1
''')
    env = {**os.environ, "NCU": mock.as_posix(), "PYTHON": Path(sys.executable).as_posix()}
    result = subprocess.run([bash, "scripts/run_ncu.sh", "--tag", "permission", "--quick", "--impls", "cufft"],
                            cwd=tmp_path, text=True, capture_output=True, env=env)
    assert result.returncode == 77, result.stdout + result.stderr
    assert "sudo -E" in result.stderr
    assert "NVreg_RestrictProfilingToAdminUsers=0" in result.stderr
    assert read_csv(tmp_path / "results/permission/ncu/index.csv")[0]["status"] == "permission_error"
