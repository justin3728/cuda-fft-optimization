import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import uuid

import pytest

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
    plans = list(re.finditer(r"NCU capture plan: impl=(\S+) N=(\d+) batch=(\d+) cache=(\w+) expected_kernels=(\S+) capture_limit=(\d+) sampled=(\w+)", result.stdout))
    assert plans
    assert sum(int(item.group(6)) for item in plans) == 352
    assert "NCU total capture upper bound: 352 kernels" in result.stdout
    fft2 = [item for item in plans if item.group(1).startswith("fft2[")]
    assert len(fft2) == 9
    assert all((item.group(5), item.group(6), item.group(7)) == ("2", "2", "false") for item in fft2)
    assert 352 <= 400


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
if [[ -n $exporting ]]; then
    printf 'synthetic report' > "$exporting.ncu-rep"
    [[ $exporting != *fft2* ]] || echo 'impl_detail=fft2 N=1048576 batch=1 N1=1024 N2=1024 C=8 R=4'
    exit 0
fi
count=1
[[ $report != *legacy_N65536* ]] || count=10
[[ $report != *cufft_N1048576* ]] || count=2
[[ $report != *fft2* ]] || count=${FFT2_MOCK_KERNELS:-2}
printf '"ID","Process ID","Kernel Name","Context","Stream","Block Size","Grid Size","Metric Name","Metric Unit","Metric Value"\\n'
for ((i=0; i<count; ++i)); do
    name=test_kernel
    if [[ $report == *fft2* ]]; then
        if ((i == 0)); then name='void fft2::pass1_columns()'; else name='void fft2::pass2_rows()'; fi
    fi
    printf '"%s","1","%s","1","7","(256, 1, 1)","(4, 1, 1)","gpu__time_duration.sum","nsecond","1000"\\n' "$i" "$name"
done
''')


def printed_commands(stdout):
    return [shlex.split(line[2:]) for line in stdout.splitlines() if line.startswith("+ ")]


def test_fft2_flags_reach_sweep_and_exact_nvtx_filters(bash):
    result = subprocess.run([bash, "scripts/run_t1_all.sh", "--tag", "fft2_flags_dry", "--dry-run", "--quick",
                             "--fft2-n1", "1024", "--fft2-tile-cols", "8", "--fft2-tile-rows", "4",
                             "--fft2-index-mode", "1", "--fft2-smem-padding", "1", "--fft2-tile-policy", "1", "--fft2-radix-mode", "2",
                             "--fft2-out-of-place"], cwd=ROOT, text=True, capture_output=True, check=True)
    commands = printed_commands(result.stdout)
    sweep = next(cmd for cmd in commands if cmd[0].endswith("/fft_bench") and "--profile" not in cmd and "--export-vkfft" not in cmd and "--versions" not in cmd)
    assert sweep[sweep.index("--impls") + 1] == "legacy,cufft,vkfft,fft2"
    for flag, value in [("--fft2-n1", "1024"), ("--fft2-tile-cols", "8"), ("--fft2-tile-rows", "4"),
                        ("--fft2-index-mode", "1"), ("--fft2-smem-padding", "1"), ("--fft2-tile-policy", "1"), ("--fft2-radix-mode", "2")]:
        assert sweep[sweep.index(flag) + 1] == value
    profiles = [cmd for cmd in commands if "--nvtx-include" in cmd and "--impls" in cmd
                and cmd[cmd.index("--impls") + 1] == "fft2"]
    assert len(profiles) == 2  # cache all and none, one execution each
    for cmd in profiles:
        assert cmd[cmd.index("--launch-count") + 1] == "2"
        assert cmd[cmd.index("--nvtx-include") + 1] == r"prof\/fft2\[n1=1024\,c=8\,r=4\,im=1\,pad=1\,tp=1\,rx=2\,oop=1\]\/N1048576\/b1/"
        assert cmd[cmd.index("--fft2-index-mode") + 1] == "1"
        assert cmd[cmd.index("--fft2-smem-padding") + 1] == "1"
        assert cmd[cmd.index("--fft2-tile-policy") + 1] == "1"
        assert cmd[cmd.index("--fft2-radix-mode") + 1] == "2"
        assert "--fft2-out-of-place" in cmd


@pytest.mark.parametrize("n1,cols,rows,index_mode,padding,oop", [
    (0, 0, 0, 0, 0, False),
    (1024, 8, 4, 0, 0, True),
    (1024, 4, 2, 1, 0, False),
    (0, 0, 0, 0, 2, False),
    (1024, 8, 4, 1, 1, True),
    (256, 1, 2, 1, 2, False),
])
@pytest.mark.parametrize("policy,radix", [(0, 0), (1, 0), (0, 1), (1, 1), (1, 2)])
def test_fft2_shell_label_matches_cpp_format(bash, n1, cols, rows, index_mode, padding, oop, policy, radix):
    # Mirror fft2_name() in bench/backends/backend.hpp, including optional-field order.
    expected = f"fft2[n1={n1},c={cols},r={rows}"
    if index_mode:
        expected += f",im={index_mode}"
    if padding:
        expected += f",pad={padding}"
    if policy:
        expected += f",tp={policy}"
    if radix:
        expected += f",rx={radix}"
    if oop:
        expected += ",oop=1"
    expected += "]"
    args = ["--tag", "label_dry", "--fft2-n1", str(n1), "--fft2-tile-cols", str(cols),
            "--fft2-tile-rows", str(rows), "--fft2-index-mode", f"0{index_mode}",
            "--fft2-smem-padding", f"0{padding}",
            "--fft2-tile-policy", f"0{policy}", "--fft2-radix-mode", f"0{radix}"]
    if oop:
        args.append("--fft2-out-of-place")
    result = subprocess.run([bash, "-c", 'source scripts/common.sh; t1_parse "$@"; t1_fft2_name',
                             "label-test", *args], cwd=ROOT, text=True, capture_output=True, check=True)
    assert result.stdout == expected


@pytest.mark.parametrize("flag,value", [
    ("--fft2-tile-policy", "2"), ("--fft2-radix-mode", "3"),
    ("--fft2-tile-policy", "-1"), ("--fft2-radix-mode", "1,2"),
    ("--fft2-radix-mode", "999999999999999999999"),
    ("--fft2-index-mode", "2"), ("--fft2-smem-padding", "3"),
    ("--fft2-index-mode", "-1"), ("--fft2-smem-padding", "1,2"),
    ("--fft2-index-mode", "999999999999999999999"),
])
def test_invalid_fft2_axes_fail_before_any_commands(bash, flag, value):
    result = subprocess.run([bash, "scripts/run_t1_all.sh", "--tag", "bad_axis_dry", "--dry-run", flag, value],
                            cwd=ROOT, text=True, capture_output=True)
    assert result.returncode == 2
    assert not printed_commands(result.stdout)


@pytest.mark.parametrize("count", [1, 2, 3])
def test_fft2_capture_requires_both_passes_and_preserves_quoted_metadata(bash, tmp_path, count):
    shutil.copytree(ROOT / "scripts", tmp_path / "scripts")
    mock = tmp_path / "mock_ncu"
    mock_successful_ncu(mock)
    env = {**os.environ, "NCU": mock.as_posix(), "PYTHON": Path(sys.executable).as_posix(),
           "FFT2_MOCK_KERNELS": str(count)}
    result = subprocess.run([bash, "scripts/run_ncu.sh", "--tag", "fft2_capture", "--impls", "fft2",
                             "--profile-log2", "20", "--profile-batch-modes", "b1", "--skip-copy-profiles",
                             "--fft2-n1", "1024", "--fft2-tile-cols", "8", "--fft2-tile-rows", "4"],
                            cwd=tmp_path, text=True, capture_output=True, env=env)
    assert result.returncode == (0 if count == 2 else 1), result.stdout + result.stderr
    rows = read_csv(tmp_path / "results/fft2_capture/ncu/index.csv")
    assert len(rows) == 2
    assert all(row["status"] == ("ok" if count == 2 else "error") for row in rows)
    assert all(row["impl"] == "fft2[n1=1024,c=8,r=4]" and row["expected_kernels"] == "2" for row in rows)
    assert all(row["captured_kernels"] == str(count) and row["sampled"] == "false" for row in rows)
    assert all("N1=1024 N2=1024 C=8 R=4" in row["impl_detail"] for row in rows)


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


@pytest.mark.parametrize("tw,cx", [(0, 0), (1, 0), (0, 1), (1, 1)])
def test_twiddle_cross_labels_and_forwarding(bash, tw, cx):
    args = ["--tag", "twcx_dry", "--fft2-twiddle-mode", f"0{tw}",
            "--fft2-cross-mode", f"0{cx}", "--fft2-radix-mode", "2", "--fft2-out-of-place"]
    expected = "fft2[n1=0,c=0,r=0,rx=2"
    if tw:
        expected += ",tw=1"
    if cx:
        expected += ",cx=1"
    expected += ",oop=1]"
    result = subprocess.run([bash, "-c", 'source scripts/common.sh; t1_parse "$@"; t1_fft2_name',
                             "test", *args], cwd=ROOT, text=True, capture_output=True, check=True)
    assert result.stdout == expected
    result = subprocess.run([bash, "scripts/run_t1_all.sh", *args, "--quick", "--dry-run"],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    commands = printed_commands(result.stdout)
    benches = [cmd for cmd in commands if "--impls" in cmd and
               "fft2" in cmd[cmd.index("--impls") + 1].split(",") and
               ("--profile" in cmd or any(part.endswith("/fft_bench") for part in cmd))]
    assert benches
    for cmd in benches:
        assert cmd[cmd.index("--fft2-twiddle-mode") + 1] == str(tw)
        assert cmd[cmd.index("--fft2-cross-mode") + 1] == str(cx)


@pytest.mark.parametrize("flag", ["--fft2-twiddle-mode", "--fft2-cross-mode"])
@pytest.mark.parametrize("value", ["2", "-1", "1,0", "99999999999999999999"])
def test_invalid_twiddle_cross_flags(bash, flag, value):
    test_invalid_fft2_axes_fail_before_any_commands(bash, flag, value)


@pytest.mark.parametrize("radix,label", [("0", ""), ("01", ",rx=1"), ("2", ",rx=2"), ("-1", ",rx=auto")])
def test_auto_radix_label_order_and_forwarding(bash, radix, label):
    args = ["--tag", "auto_radix_dry", "--fft2-tile-policy", "1", "--fft2-radix-mode", radix,
            "--fft2-twiddle-mode", "1", "--fft2-cross-mode", "1", "--fft2-out-of-place"]
    result = subprocess.run([bash, "-c", 'source scripts/common.sh; t1_parse "$@"; t1_fft2_name',
                             "test", *args], cwd=ROOT, text=True, capture_output=True, check=True)
    assert result.stdout == "fft2[n1=0,c=0,r=0,tp=1" + label + ",tw=1,cx=1,oop=1]"
    result = subprocess.run([bash, "scripts/run_sweep.sh", *args, "--dry-run"],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    assert "--fft2-radix-mode " + str(int(radix)) in result.stdout


@pytest.mark.parametrize("value", ["-2", "-01", "auto", "1,2", "99999999999"])
def test_invalid_auto_radix_flags(bash, value):
    test_invalid_fft2_axes_fail_before_any_commands(bash, "--fft2-radix-mode", value)
