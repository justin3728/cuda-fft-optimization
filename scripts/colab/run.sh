#!/usr/bin/env bash
# Run one command on a fresh Colab runtime and fetch its results, end to end:
#   allocate -> clone branch -> run -> poll -> download -> ALWAYS stop.
#
# Runs from Git Bash on the owner's Windows PC; the Colab CLI lives in WSL
# (see CLAUDE.md "Running GPU jobs"). Allocating a runtime costs compute
# units: get the owner's OK before calling this with --gpu A100/L4.
#
# Usage:
#   scripts/colab/run.sh --gpu L4|A100|none --branch BRANCH --cmd 'COMMAND' \
#       [--fetch PATH_IN_REPO] [--dest LOCAL_DIR] [--name SESSION] \
#       [--timeout-min 90] [--keep]
#
# COMMAND runs with bash in the cloned repo root. Its exit code is reported
# and becomes this script's exit code. --fetch is a path relative to the repo
# root (file or directory, build/ dirs excluded) packed and extracted under
# --dest (default: $TMP/colab_runs/SESSION). Logs always land in --dest.
set -uo pipefail
# Git Bash would rewrite /mnt/c/... arguments passed to wsl.exe into C:/Program Files/Git/...
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

gpu='' branch='' cmd='' fetch='' dest='' name='' timeout_min=90 keep=0
repo_url=${COLAB_REPO_URL:-https://github.com/justin3728/cuda-fft-optimization}
while (($#)); do
    case $1 in
        --gpu) gpu=$2; shift 2;;
        --branch) branch=$2; shift 2;;
        --cmd) cmd=$2; shift 2;;
        --fetch) fetch=$2; shift 2;;
        --dest) dest=$2; shift 2;;
        --name) name=$2; shift 2;;
        --timeout-min) timeout_min=$2; shift 2;;
        --keep) keep=1; shift;;
        -h|--help) sed -n '2,20p' "$0"; exit 0;;
        *) echo "unknown argument: $1" >&2; exit 2;;
    esac
done
[[ $gpu =~ ^(L4|A100|T4|H100|none)$ ]] || { echo '--gpu must be L4, A100, T4, H100 or none' >&2; exit 2; }
[[ -n $branch && -n $cmd ]] || { echo '--branch and --cmd are required' >&2; exit 2; }
[[ $timeout_min =~ ^[0-9]+$ ]] || { echo '--timeout-min must be an integer' >&2; exit 2; }
name=${name:-run$(date +%m%d%H%M)}
[[ $name =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'invalid --name' >&2; exit 2; }
dest=${dest:-${TMP:-/tmp}/colab_runs/$name}
# Unix-style path: Git Bash tar treats "C:" in C:... as a remote host.
dest=$(cygpath -u "$dest")
mkdir -p "$dest"
log() { printf '[colab-run %s] %s\n' "$(date +%T)" "$*" >&2; }

# colab CLI in WSL; arguments are passed through without re-quoting.
colab() { wsl -e bash -lc 'colab --auth oauth2 "$@"' colab "$@"; }
to_wsl() { wsl -e wslpath -a "$(cygpath -w "$1")"; }

stopped=0
# Invoked through trap.
# shellcheck disable=SC2329
cleanup() {
    if ((keep == 0 && stopped == 0)); then
        log "stopping session $name"
        colab stop -s "$name" >&2 || log "WARNING: stop failed; check 'colab sessions'"
        stopped=1
    fi
}
trap cleanup EXIT INT TERM

# --- remote job script --------------------------------------------------------
work=$(mktemp -d)
q() { printf '%q' "$1"; }
cat > "$work/job.sh" <<EOF
#!/usr/bin/env bash
set -uo pipefail
cd /content && rm -rf repo
{
  echo "branch=$(q "$branch")"
  if git clone -q --recurse-submodules -b $(q "$branch") $(q "$repo_url") repo && cd repo; then
    git log --oneline -1
    [ ! -f scripts/analysis/requirements.txt ] || pip install -q -r scripts/analysis/requirements.txt
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo 'no GPU'
    echo "=== command ==="
    bash -c $(q "$cmd")
    echo "EXIT=\$?"
  else
    echo "clone of branch failed"
    echo "EXIT=90"
  fi
} > /content/job.log 2>&1
code=\$(grep -o 'EXIT=[0-9]*' /content/job.log | tail -1 | cut -d= -f2)
echo "\${code:-99}" > /content/job_exit
if [ -n $(q "$fetch") ] && [ -e /content/repo/$(q "$fetch") ]; then
  tar czf /content/job_out.tgz -C /content/repo --exclude='*/build' -- $(q "$fetch")
fi
touch /content/job_done
EOF
cat > "$work/start.py" <<'EOF'
import subprocess
subprocess.Popen(["bash", "-c", "rm -f /content/job_done; chmod +x /content/job.sh; nohup /content/job.sh > /content/job_outer.log 2>&1 &"])
print("started")
EOF
cat > "$work/status.py" <<'EOF'
import os
print("JOBDONE" if os.path.exists("/content/job_done") else "RUNNING")
EOF

# --- allocate (one retry) -----------------------------------------------------
accel=(); [[ $gpu == none ]] || accel=(--gpu "$gpu")
allocated=0
for attempt in 1 2; do
    log "allocating $gpu as $name (attempt $attempt)"
    if colab new -s "$name" "${accel[@]}" >&2 && colab sessions 2>/dev/null | grep -q "\[$name\]"; then
        allocated=1; break
    fi
done
if ((allocated == 0)); then log "allocation failed"; exit 3; fi
colab sessions 2>/dev/null | grep "\[$name\]" >&2
colab usage 2>/dev/null | grep -i rate >&2

# --- run and poll -------------------------------------------------------------
colab upload -s "$name" "$(to_wsl "$work/job.sh")" /content/job.sh >&2 || exit 4
colab exec -s "$name" -f "$(to_wsl "$work/start.py")" >&2 || exit 4
status_py=$(to_wsl "$work/status.py")
deadline=$((SECONDS + timeout_min * 60))
while :; do
    state=$(colab exec -s "$name" -f "$status_py" 2>/dev/null | tail -1)
    [[ $state == JOBDONE ]] && break
    if ((SECONDS > deadline)); then log "timeout after $timeout_min min"; break; fi
    sleep 60
done

# --- fetch ----------------------------------------------------------------------
dest_wsl=$(to_wsl "$dest")
colab download -s "$name" /content/job.log "$dest_wsl/job.log" >&2 || log 'no job.log'
colab download -s "$name" /content/job_exit "$dest_wsl/job_exit" >&2 || true
if [[ -n $fetch ]]; then
    if colab download -s "$name" /content/job_out.tgz "$dest_wsl/job_out.tgz" >&2; then
        tar xzf "$dest/job_out.tgz" -C "$dest" && rm -f "$dest/job_out.tgz"
    else
        log "WARNING: nothing fetched for $fetch"
    fi
fi
code=$(cat "$dest/job_exit" 2>/dev/null || echo 99)
log "job exit code: $code; outputs in $dest"
tail -n 30 "$dest/job.log" >&2 || true
[[ $code =~ ^[0-9]+$ ]] || code=99
exit "$code"
