#!/usr/bin/env bash
# Fast-forward /root/NixConfig on Ramsay from origin/main and switch the system to it.
#
#   scripts/deploy-ramsay.sh                  fetch + merge + submodules + switch
#   scripts/deploy-ramsay.sh --check          fetch + merge + submodules only
#   scripts/deploy-ramsay.sh --host HOST      use HOST as the only target
#   scripts/deploy-ramsay.sh --no-submodules  skip the submodule update
#
# The remote login shell is nushell, so each command goes through bash -lc.
# The sudo rule allows wheel without a password, so nh os switch needs no tty.
# TTY=1 forces ssh -t when nh asks for a terminal anyway.
#
# HOST, ATTR, DEST, REPO_URL and TTY override the defaults below.
set -euo pipefail

HOST=${HOST:-}
ATTR=${ATTR:-Ramsay}
DEST=${DEST:-/root/NixConfig}
REPO_URL=${REPO_URL:-https://github.com/mattgmak/NixConfig}
TTY=${TTY:-0}
CANDIDATES=(ramsay.dab-octatonic.ts.net 192.168.50.69)

check=0
no_submodules=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) check=1 ;;
    --host)
      if [ $# -lt 2 ]; then
        printf 'deploy-ramsay: --host needs a value\n' >&2
        exit 2
      fi
      HOST=$2
      shift
      ;;
    --no-submodules) no_submodules=1 ;;
    --help | -h)
      cat <<'EOF'
Usage: deploy-ramsay.sh [--check] [--host HOST] [--no-submodules] [--help]

  --check          run the git steps and stop before nh os switch
  --host HOST      use HOST as the only target
  --no-submodules  skip the submodule update
  --help           print this text and exit

The default target order is the tailnet name, then the LAN address.
The SSH user is root.
EOF
      exit 0
      ;;
    *)
      printf 'deploy-ramsay: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { printf 'deploy-ramsay: %s\n' "$*"; }

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=6)

# nushell parses the far side, so the payload travels as one single-quoted word.
# shellcheck disable=SC2029  # the payload must expand here, so the far side gets the paths.
remote() {
  case "$1" in
    *"'"*)
      log 'error: internal remote command holds a single quote'
      exit 1
      ;;
  esac
  if [ "$TTY" = 1 ]; then
    ssh -t "${ssh_opts[@]}" "$host" "bash -lc '$1'"
  else
    ssh "${ssh_opts[@]}" "$host" "bash -lc '$1'"
  fi
}

case "$HOST" in
  "") ;;
  *@*) ;;
  *) HOST="root@$HOST" ;;
esac

if [ -n "$HOST" ]; then
  candidates=("$HOST")
else
  candidates=()
  for c in "${CANDIDATES[@]}"; do
    candidates+=("root@$c")
  done
fi

host=
for c in "${candidates[@]}"; do
  if ssh "${ssh_opts[@]}" "$c" true >/dev/null 2>&1; then
    host=$c
    break
  fi
  log "unreachable: $c"
done

if [ -z "$host" ]; then
  log "error: no reachable target, tried: ${candidates[*]}"
  exit 1
fi
log "target $host"

clone_cmd="git clone --recurse-submodules -b main $REPO_URL $DEST"
if remote "test -d $DEST/.git"; then
  log "repo $DEST is present"
elif remote "test -z \"\$(ls -A $DEST 2>/dev/null)\""; then
  # deploy-goofeus clones a missing repo the same way, so the first run works.
  log "cloning $REPO_URL -> $DEST"
  remote "$clone_cmd"
else
  log "error: $DEST exists and is not a git clone"
  log "run this on $host to repair it: $clone_cmd"
  exit 1
fi

log 'fetching origin/main'
remote "git -C $DEST fetch --prune origin main"

log 'fast-forwarding to origin/main'
if ! remote "git -C $DEST merge --ff-only origin/main"; then
  log "error: merge is not a fast-forward, $DEST holds work that origin/main lacks"
  remote "git -C $DEST status -sb | head -5" || true
  exit 1
fi

if [ "$no_submodules" = 0 ]; then
  log 'updating submodules'
  remote "git -C $DEST submodule update --init --recursive"
fi

rev=$(remote "git -C $DEST rev-parse --short HEAD")
log "at revision $rev"

if [ "$check" = 1 ]; then
  log '--check: skipping switch'
  exit 0
fi

log 'switching'
# -e none skips nh's root refusal. Ramsay runs as root by design.
if ! remote "cd $DEST && NH_OS_FLAKE=$DEST nh os switch -e none .#$ATTR"; then
  log 'error: nh os switch failed'
  exit 1
fi
log 'switched'
