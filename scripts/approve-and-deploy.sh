#!/usr/bin/env bash
# Land a worktree branch and deploy it from one keystroke in a prefilled pane.
#
# The agent finishes a branch, then opens a pane in the same tmux window with
# this command typed but not entered:
#
#   scripts/approve-and-deploy.sh fix-ramsay-agenix --caller %4
#
# You read it and press Enter. The script merges the branch into main, pushes,
# deploys through the ramsay-deploy gate, prompts the agent pane to verify the
# running system, then closes its own pane. Only the pi session stays open.
#
#   scripts/approve-and-deploy.sh <branch>                  ramsay only
#   scripts/approve-and-deploy.sh <branch> --hosts ramsay,goofeus
#   scripts/approve-and-deploy.sh <branch> --dry-run        print every step
#   scripts/approve-and-deploy.sh <branch> --no-deploy      merge and push only
#   scripts/approve-and-deploy.sh <branch> --no-kill        keep the pane open
#
# Run it as the agent user. The two sudo calls need the NOPASSWD rules in
# dendritic/hosts/Ramsay.nix, so no password is typed on a phone session.
# A failed step stops the run and leaves the pane open with the log on screen.
set -euo pipefail

usage() { sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
say() { printf '\n== %s\n' "$*"; }
run() {
  if [ "$dry" = 1 ]; then printf '  dry: %s\n' "$*"; return 0; fi
  printf '  run: %s\n' "$*"
  "$@"
}

branch=''
hosts='ramsay'
dry=0
no_deploy=0
no_kill=0
allow_dirty=0
caller=${APPROVE_CALLER:-}
msg=${APPROVE_MSG:-}
host_required=${HOST_REQUIRED:-Ramsay}

while [ $# -gt 0 ]; do
  case "$1" in
    --hosts)       hosts=${2:?--hosts needs a value}; shift 2 ;;
    --dry-run|-n)  dry=1; shift ;;
    --no-deploy)   no_deploy=1; shift ;;
    --no-kill)     no_kill=1; shift ;;
    --caller)      caller=${2:?--caller needs a value}; shift 2 ;;
    --msg)         msg=${2:?--msg needs a value}; shift 2 ;;
    --allow-dirty) allow_dirty=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    -*)            printf 'unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *)             [ -z "$branch" ] || { printf 'extra argument: %s\n' "$1" >&2; exit 2; }
                   branch=$1; shift ;;
  esac
done

[ -n "$branch" ] || { usage >&2; exit 2; }
[ "$dry" = 1 ] || [ -n "$caller" ] || {
  printf 'no --caller pane: the verify prompt has nowhere to go\n' >&2
  printf 'pass the pi pane id, or use --dry-run\n' >&2
  exit 2
}

case "$(hostname -s)" in
  "$host_required") : ;;
  *) printf 'this script runs on %s, not on %s\n' "$(hostname -s)" "$host_required" >&2
     exit 1 ;;
esac

command -v wt >/dev/null || { printf 'wt not in PATH\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'jq not in PATH\n' >&2; exit 1; }

wt_path=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$wt_path" ] || { printf 'not inside a git checkout\n' >&2; exit 1; }
[ "$(git -C "$wt_path" branch --show-current)" = "$branch" ] || {
  printf '%s is not the branch checked out at %s\n' "$branch" "$wt_path" >&2
  exit 1
}
if [ "$allow_dirty" != 1 ] && [ -n "$(git -C "$wt_path" status --porcelain)" ]; then
  printf 'uncommitted changes in %s: commit them first, or pass --allow-dirty\n' "$wt_path" >&2
  exit 1
fi

main_path=$(wt list --format json 2>/dev/null |
  jq -r '.[] | select(.main_state == "is_main") | .path' | head -1)
[ -n "$main_path" ] || { printf 'cannot find the main worktree from wt list\n' >&2; exit 1; }
[ "$main_path" != "$wt_path" ] || {
  printf 'the main checkout cannot merge itself: run me from a worktree\n' >&2
  exit 1
}

for h in ${hosts//,/ }; do
  case "$h" in ramsay | goofeus) : ;; *) printf 'unknown host: %s\n' "$h" >&2; exit 2 ;; esac
done

log=${LOG:-${TMPDIR:-/tmp}/agent-tmp/NixConfig/approve-and-deploy-${branch}.log}
[ "$dry" = 1 ] || mkdir -p "$(dirname "$log")"

main() {
  printf 'branch  %s (%s)\nmain    %s\nhosts   %s\nlog     %s\n' \
    "$branch" "$wt_path" "$main_path" "$hosts" "$log"

  say 'merge'
  run wt -C "$wt_path" merge main
  local sha
  sha=$(git -C "$main_path" rev-parse --short HEAD)
  printf '  main is now %s\n' "$sha"

  say 'push'
  run git -C "$main_path" push origin main

  if [ "$no_deploy" = 1 ]; then
    say 'deploy skipped (--no-deploy)'
  else
    case ",$hosts," in
      *,ramsay,*)
        say 'deploy ramsay'
        run sudo ramsay-deploy-approve
        run sudo ramsay-deploy-switch
        ;;
    esac
    case ",$hosts," in
      *,goofeus,*)
        say 'deploy goofeus'
        run bash "$main_path/scripts/deploy-goofeus.sh"
        ;;
    esac
  fi

  [ -n "$msg" ] || msg="Deploy of $sha finished. Check journalctl for the units you changed, then report the result."
  say 'prompt the agent pane'
  printf '  -> %s: %s\n' "$caller" "$msg"
  if [ "$dry" != 1 ]; then
    tmux send-keys -t "$caller" -l "$msg"
    tmux send-keys -t "$caller" Enter
  fi

  if [ "$no_kill" = 1 ] || [ "$dry" = 1 ]; then
    say 'pane kept open'
  elif [ -n "${TMUX_PANE:-}" ]; then
    say 'close this pane'
    tmux kill-pane -t "$TMUX_PANE"
  fi
}

on_err() {
  printf '\nFAILED at line %s -- pane stays open, log at %s\n' "$1" "$log" >&2
  exit 1
}
trap 'on_err $LINENO' ERR

if [ "$dry" = 1 ]; then
  main
else
  main 2>&1 | tee "$log"
fi
