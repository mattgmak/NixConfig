#!/usr/bin/env bash
# Land a worktree branch and deploy it from one keystroke in a prefilled pane.
#
# The agent finishes a branch, then opens a pane in the same tmux window with
# this command typed but not entered:
#
#   scripts/approve-and-deploy.sh fix-ramsay-agenix --caller %4
#
# You read it and press Enter. The script merges the branch into main, pushes,
# runs the deploy action for each host, then sends the handoff to the pi pane.
# The merge keeps the worktree, so the caller session keeps a live cwd. The
# handoff tells that session to remove the worktree once it verifies the deploy.
# A failed step sends the failure to the same pane and keeps the pane open.
#
#   scripts/approve-and-deploy.sh <branch>              host = hostname -s
#   scripts/approve-and-deploy.sh <branch> --hosts ramsay,goofeus
#   scripts/approve-and-deploy.sh <branch> --dry-run        print every step
#   scripts/approve-and-deploy.sh <branch> --no-deploy      merge and push only
#   scripts/approve-and-deploy.sh <branch> --no-kill        keep the pane open
#   scripts/approve-and-deploy.sh <branch> --handoff <file> replace the handoff text
#
# deploy_action() maps a host to its deploy action. Ramsay runs the sudo gate
# from dendritic/hosts/Ramsay.nix and works only there. Goofeus deploys over
# ssh. GoofyDesky, GoofyEnvy and MacMini print the switch command, because the
# user runs nh for the current machine.
# A failed step stops the run and leaves the pane open with the log on screen.
set -euo pipefail

usage() { sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
send_to_caller() {
  if [ "$dry" = 1 ] || [ -z "$caller" ]; then printf '  -> %s: %s\n' "$caller" "$1"; return 0; fi
  tmux send-keys -t "$caller" -l "$1"
  tmux send-keys -t "$caller" Enter
}
say() { printf '\n== %s\n' "$*"; }
run() {
  if [ "$dry" = 1 ]; then printf '  dry: %s\n' "$*"; return 0; fi
  printf '  run: %s\n' "$*"
  "$@"
}

# deploy_action <host> prints run: lines to execute and print: lines to show.
# Ramsay's sudo gate needs the NOPASSWD rules in dendritic/hosts/Ramsay.nix, so
# it runs only on Ramsay. A print: host never runs nh from here.
deploy_action() {
  local h=${1,,}
  case "$h" in
    ramsay)
      [ "$(hostname -s)" = Ramsay ] || { printf 'deploy ramsay only on ramsay\n' >&2; return 1; }
      printf 'run:sudo /run/current-system/sw/bin/ramsay-deploy-approve\n'
      printf 'run:sudo /run/current-system/sw/bin/ramsay-deploy-switch\n' ;;
    goofeus)
      printf 'run:bash %s/scripts/deploy-goofeus.sh\n' "$main_path" ;;
    goofydesky)
      [ "$(hostname -s)" = GoofyDesky ] || { printf 'deploy goofydesky only on goofydesky\n' >&2; return 1; }
      printf 'run:sudo /run/current-system/sw/bin/nh os switch -e none --diff never %s#GoofyDesky\n' "$main_path" ;;
    goofyenvy)
      [ "$(hostname -s)" = GoofyEnvy ] || { printf 'deploy goofyenvy only on goofyenvy\n' >&2; return 1; }
      printf 'run:sudo /run/current-system/sw/bin/nh os switch -e none --diff never %s#GoofyEnvy\n' "$main_path" ;;
    macmini)    printf 'print:nh darwin switch --flake %s#MacMini\n' "$main_path" ;;
    *) printf 'no deploy action for host: %s\n' "$h" >&2; return 1 ;;
  esac
}

branch=''
hosts=${HOSTS:-$(hostname -s)}
dry=0
no_deploy=0
no_kill=0
allow_dirty=0
deploy_ran=0
main_path=''
caller=${APPROVE_CALLER:-}
msg=${APPROVE_MSG:-}
handoff=${APPROVE_HANDOFF:-}

while [ $# -gt 0 ]; do
  case "$1" in
    --hosts)       hosts=${2:?--hosts needs a value}; shift 2 ;;
    --dry-run|-n)  dry=1; shift ;;
    --no-deploy)   no_deploy=1; shift ;;
    --no-kill)     no_kill=1; shift ;;
    --caller)      caller=${2:?--caller needs a value}; shift 2 ;;
    --msg)         msg=${2:?--msg needs a value}; shift 2 ;;
    --handoff)     handoff=${2:?--handoff needs a value}; shift 2 ;;
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

for h in ${hosts//,/ }; do
  deploy_action "$h" >/dev/null || exit 2
done

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

log=${LOG:-${TMPDIR:-/tmp}/agent-tmp/NixConfig/approve-and-deploy-${branch}.log}
[ "$dry" = 1 ] || mkdir -p "$(dirname "$log")"

main() {
  printf 'branch  %s (%s)\nmain    %s\nhosts   %s\nlog     %s\n' \
    "$branch" "$wt_path" "$main_path" "$hosts" "$log"

  say 'merge'
  # --no-remove keeps the worktree alive. A caller session started there keeps a
  # live cwd, and a bad deploy can be rebased onto main in the same worktree.
  run wt -C "$wt_path" merge main --no-remove
  local sha
  sha=$(git -C "$main_path" rev-parse --short HEAD)
  printf '  main is now %s\n' "$sha"

  say 'push'
  run git -C "$main_path" push origin main

  say 'sync submodules'
  # The deploy gate commits unstaged drift in the main checkout. A submodule
  # left behind by the merge counts as drift and reverts the pointer it set.
  run git -C "$main_path" submodule update --quiet

  if [ "$no_deploy" = 1 ]; then
    say 'deploy skipped (--no-deploy)'
  else
    for h in ${hosts//,/ }; do
      say "deploy $h"
      while IFS= read -r line; do
        case "$line" in
          run:*)
            deploy_ran=1
            run ${line#run:}
            ;;
          print:*) printf '  manual: %s\n' "${line#print:}" ;;
        esac
      done < <(deploy_action "$h")
    done
  fi

  # The pi session is the worktree memory. The handoff line replaces the old
  # HANDOFF.md file: the session keeps the context, and git keeps the change.
  local msg=${msg:-}
  if [ -n "$handoff" ] && [ -f "$handoff" ]; then
    msg=$(tr '\n' ' ' < "$handoff")
  elif [ -n "$msg" ]; then
    :
  elif [ "$no_deploy" = 1 ]; then
    msg="Branch $branch merged as $sha, deploy skipped. Report the result."
  elif [ "$deploy_ran" = 0 ]; then
    msg="Branch $branch merged as $sha, deploy left to you. Run the printed switch command, then report the result."
  else
    msg="Deploy of $sha finished. Read the log at $log, check journalctl, then report the result."
  fi
  # The worktree survives the merge, so the caller owns its cleanup. Remove comes
  # last: deleting the worktree deletes the cwd of the session running it.
  msg="$msg If the deploy is good, run 'wt remove -f -D $branch' as your last action. If it is bad, rebase the worktree onto main, fix on top, and run the approval flow again."
  send_to_caller "$msg"

  if [ "$no_kill" = 1 ] || [ "$dry" = 1 ]; then
    say 'pane kept open'
  elif [ -n "${TMUX_PANE:-}" ]; then
    say 'close this pane'
    tmux kill-pane -t "$TMUX_PANE"
  fi
}

on_err() {
  local where=${2:-main} err
  printf '\nFAILED at line %s in %s -- pane stays open, log at %s\n' "$1" "$where" "$log" >&2
  err=${msg:-}
  if [ -z "$err" ]; then
    err="Deploy failed in $where at line $1. Read the log at $log, fix it, then report the result."
  fi
  send_to_caller "$err" || true
  exit 1
}
trap 'on_err "$LINENO" "${FUNCNAME[0]:-top}"' ERR

if [ "$dry" = 1 ]; then
  main
else
  main 2>&1 | tee "$log"
fi
