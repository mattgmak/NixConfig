#!/usr/bin/env bash
# Detached tmux pi worker + optional graceful parent handoff.
#
# Usage:
#   PI_HANDOFF_QUIT=1 launch-worker.sh <worktree_path> <prompt> [branch] [label] [url] [session_name]
#
# Args 3–5 feed handoff report. Prompt: escape single quotes for shell ('\'').
# Deferred parent /quit fires only when PI_HANDOFF_QUIT=1.
# Report file: ${PI_REPORT_FILE:-${TMPDIR:-/tmp}/agent-tmp/agent-handoff-report.txt}
set -euo pipefail

worktree_path="${1:?worktree_path required}"
prompt="${2:?prompt required}"
branch="${3:-unknown}"
issue="${4:-unknown}"
url="${5:-}"
session_override="${6:-}"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/parent-quit.sh
source "$script_dir/lib/parent-quit.sh"

session=''
skip_derive=0

# 1) Explicit session name wins — spawn-pi passes arg 6 so workers never
# collide with the parent's pi or other busy sessions
if [ -n "$session_override" ]; then
  # tmux treats '.' & ':' in -t as window/pane separators (can't find pane gotcha)
  session=$(printf '%s' "$session_override" | tr '.:' '__' | tr ' ' '_')
  skip_derive=1
else
  # Reuse existing tmux session rooted at this worktree — but only when no
  # pi is already running in it (running pi = someone else's task; silently
  # swallowing the prompt would strand the work)
  reuse_candidate=$(sesh list -j | jq -r --arg p "$worktree_path" '.[] | select(.Path == $p and .Src == "tmux") | .Name' | head -1)
  if [ -n "$reuse_candidate" ]; then
    if tmux list-panes -t "$reuse_candidate" -F '#{pane_current_command}' 2>/dev/null | grep -qE '^(node|bun|pi)$'; then
      echo "WARN: session $reuse_candidate already runs pi for a different task — prompt NOT sent" >&2
      echo "SESSION=$reuse_candidate"
      exit 0
    fi
    session=$reuse_candidate
  fi
fi

# 2) Else derive sesh-style git name (gitName + convertToValidName)
if [ "$skip_derive" = 0 ]; then
  main_root=$(git -C "$worktree_path" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  rel="${worktree_path#$main_root}"
  repo_parts=$(printf '%s' "$main_root" | tr '/' '\n' | tail -2 | paste -sd/ -)
  session=$(printf '%s%s' "$repo_parts" "$rel" | tr '.:' '__' | tr ' ' '_')
  # Distinctness: if name taken by a busy pi, bump to -2, -3, ...
  while tmux has-session -t "$session" 2>/dev/null \
      && tmux list-panes -t "$session" -F '#{pane_current_command}' 2>/dev/null | grep -qE '^(node|bun|pi)$'; do
    case "$session" in *-[0-9]) n=${session##*-}; session="${session%-*}-$((n+1))" ;; *) session="$session-2" ;; esac
  done
fi

# pi's foreground process name differs by runtime: node (node pi), bun (bun-compiled pi),
# pi (self-contained native binary)
pi_running() {
  tmux list-panes -t "$session" -F '#{pane_current_command}' 2>/dev/null | grep -qE '^(node|bun|pi)$'
}

# 3) Create session if missing — no settle sleep: tmux queues send-keys for
# pane input, poll loop below is the real gate
if ! tmux has-session -t "$session" 2>/dev/null; then
  if tmux new-session -d -s "$session" -c "$worktree_path"; then
    echo "created session: $session"
  else
    # Race: another process may create the same session name coincidentally.
    # Fall through and verify it exists before giving up.
    echo "WARN: new-session failed for $session — checking for external creation" >&2
  fi
fi
if ! tmux has-session -t "$session" 2>/dev/null; then
  echo "ERROR: tmux session $session does not exist and could not be created" >&2
  exit 1
fi

# 4) Launch pi unless already running
if pi_running; then
  echo "reusing existing pi session: $session"
else
  tmux send-keys -t "$session" "pi '$prompt'" Enter
  echo "sent pi prompt"
fi

# 5) Verify pi up — exponential backoff; pi usually up ~1–2s, ~11s budget
ok=''
for gap in 0.5 0.5 1 2 4 3; do
  if pi_running; then ok=1; break; fi
  sleep "$gap"
done
pi_running && ok=1

if [ -n "$ok" ]; then
  echo "pi confirmed running"
  echo "SESSION=$session"
else
  echo "WARN: pi not detected in $session — attach + check manually" >&2
  echo "SESSION=$session"
  echo "NOTE: handoff failed — parent agent left alive" >&2
  exit 1
fi

# 6) Handoff report — stdout + durable file (parent may quit before render)
report_file="${PI_REPORT_FILE:-${TMPDIR:-/tmp}/agent-tmp/agent-handoff-report.txt}"
mkdir -p "$(dirname "$report_file")"
{
  echo ""
  echo "=== pi handoff $(date '+%Y-%m-%d %H:%M:%S') ==="
  echo "Label:      $issue"
  [ -n "$url" ] && echo "URL:        $url"
  echo "Branch:     $branch"
  echo "Worktree:   $worktree_path"
  echo "Tmux:       $session"
  echo "Attach:     sesh connect $worktree_path   |   tmux attach -t $session"
  echo "Report:     $report_file"
} | tee -a "$report_file"

# 7) Deferred parent exit — opt-in via PI_HANDOFF_QUIT=1 (spawn-pi fans out
# multiple workers and keeps the parent; linear-ticket single handoff sets the env)
if [ "${PI_HANDOFF_QUIT:-0}" = "1" ] && schedule_parent_quit; then
  exit 0
fi

echo "handoff succeeded; session: $session; report: $report_file" >&2
exit 0
