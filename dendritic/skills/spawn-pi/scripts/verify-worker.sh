#!/usr/bin/env bash
# Read-only worker status probe. No tmux mutation — safe to run against the
# parent's own session or any spawned worker at any time.
#
# Usage: verify-worker.sh [--wait <seconds>] [--lines <n>] [--marker <text>] [--marker-file <path>] <session[:window]>
#
#   --wait        poll budget for pi to appear, default 5 (0 = single check)
#   --lines       pane tail lines printed, default 40
#   --marker      text to probe for in the input box (e.g. prompt tail) — precise
#                 unsubmitted check; without it the box/scrollback heuristics run
#   --marker-file prompt file used for the launch (launcher's PromptFile:) — last
#                 24 non-space chars become the marker
#
# Exit: 0 pi running · 3 pi not running within budget · 1 usage/target error
set -euo pipefail

wait_secs=5
lines=40
marker=''
marker_file=''
target=''

while [ $# -gt 0 ]; do
  case "$1" in
    --wait) [ $# -ge 2 ] || { echo "ERROR: --wait needs a value" >&2; exit 1; }; wait_secs=$2; shift 2 ;;
    --wait=*) wait_secs=${1#*=}; shift ;;
    --lines) [ $# -ge 2 ] || { echo "ERROR: --lines needs a value" >&2; exit 1; }; lines=$2; shift 2 ;;
    --lines=*) lines=${1#*=}; shift ;;
    --marker) [ $# -ge 2 ] || { echo "ERROR: --marker needs a value" >&2; exit 1; }; marker=$2; shift 2 ;;
    --marker=*) marker=${1#*=}; shift ;;
    --marker-file) [ $# -ge 2 ] || { echo "ERROR: --marker-file needs a path" >&2; exit 1; }; marker_file=$2; shift 2 ;;
    --marker-file=*) marker_file=${1#*=}; shift ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    *) target=$1; shift ;;
  esac
done

if [ -z "$target" ]; then
  echo "usage: verify-worker.sh [--wait N] [--lines N] [--marker TEXT|--marker-file PATH] <session[:window]>" >&2
  exit 1
fi
case "$wait_secs" in ''|*[!0-9]*) echo "ERROR: --wait needs a non-negative integer" >&2; exit 1 ;; esac
case "$lines" in ''|*[!0-9]*) echo "ERROR: --lines needs a non-negative integer" >&2; exit 1 ;; esac

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/pane-state.sh
source "$script_dir/lib/pane-state.sh"

marker=$(squeeze_ws "$marker")
if [ -n "$marker_file" ]; then
  if [ ! -r "$marker_file" ]; then
    echo "ERROR: --marker-file not readable: $marker_file" >&2
    exit 1
  fi
  [ -n "$marker" ] || marker=$(tail_marker "$(cat "$marker_file")")
fi
precise=0
if [ "${#marker}" -ge 8 ]; then
  precise=1
elif [ -n "$marker" ]; then
  echo "WARN: marker shorter than 8 chars — falling back to pane heuristics" >&2
fi

session=${target%%:*}
window=''
[ "$target" != "$session" ] && window=${target#*:}

if ! tmux has-session -t "$session" 2>/dev/null; then
  echo "ERROR: no tmux session: $session" >&2
  exit 1
fi
if [ -n "$window" ] && ! window_exists "$target"; then
  echo "ERROR: no window $window in session $session" >&2
  exit 1
fi

deadline=$(($(date +%s) + wait_secs))
while ! pi_at "$target" && [ "$(date +%s)" -lt "$deadline" ]; do
  sleep 1
done

if pi_at "$target"; then
  running=running
else
  running=not-running
fi

cwd=$(tmux display-message -p -t "$target" '#{pane_current_path}' 2>/dev/null || true)
model=$(model_from_pane "$target" 120 2>/dev/null || true)
last=$(pane_last_line "$target" 400 2>/dev/null || true)

if [ "$running" != running ]; then
  prompt=unknown
elif [ "$precise" = 1 ]; then
  # precision mode: needle in the box-line = still sitting in the input box
  if pane_box_line_matches "$target" "$marker"; then prompt=unsubmitted; else prompt=submitted; fi
elif pane_box_has_text "$target"; then
  prompt=unsubmitted
elif pane_has_submitted_message "$target"; then
  prompt=submitted
else
  prompt=unknown
fi

echo "TARGET=$target"
echo "SESSION=$session"
[ -n "$window" ] && echo "WINDOW=$target"
echo "PI=$running"
[ -n "$cwd" ] && echo "CWD=$cwd"
echo "PROMPT=$prompt"
echo "MODEL=${model:-unknown}"
echo "TASK=${last:-unknown}"
[ "$precise" = 1 ] && echo "MARKER=${marker}" || true
echo "--- pane tail (last $lines non-blank kept) ---"
pane_capture "$target" 400 | sed -e 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$' | tail -"$lines" || true

[ "$running" = running ] || exit 3
exit 0
