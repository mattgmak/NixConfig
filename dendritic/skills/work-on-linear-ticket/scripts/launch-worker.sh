#!/usr/bin/env bash
# Detached tmux pi worker for Linear ticket worktree + graceful parent handoff.
#
# Usage:
#   launch-worker.sh <worktree_path> <prompt> [branch] [issue_label] [issue_url]
#
# Args 3–5 feed handoff report. Prompt: escape single quotes for shell ('\'').
# Report file: ${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt
set -euo pipefail

worktree_path="${1:?worktree_path required}"
prompt="${2:?prompt required}"
branch="${3:-unknown}"
issue="${4:-unknown}"
url="${5:-unknown}"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/parent-quit.sh
source "$script_dir/lib/parent-quit.sh"

# 1) Reuse existing tmux session rooted at this worktree
session=$(sesh list -j | jq -r --arg p "$worktree_path" '.[] | select(.Path == $p and .Src == "tmux") | .Name' | head -1)

# 2) Else derive sesh-style git name (gitName + convertToValidName)
if [ -z "$session" ]; then
  main_root=$(git -C "$worktree_path" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  rel="${worktree_path#$main_root}"
  repo_parts=$(printf '%s' "$main_root" | tr '/' '\n' | tail -2 | paste -sd/ -)
  session=$(printf '%s%s' "$repo_parts" "$rel" | tr '.:' '__' | tr ' ' '_')
fi

# pi runs under node; idle pane shows shell
pi_running() {
  tmux list-panes -t "$session" -F '#{pane_current_command}' 2>/dev/null | grep -q '^node$'
}

# 3) Create session if missing
if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux new-session -d -s "$session" -c "$worktree_path"
  echo "created session: $session"
  sleep 1
fi

# 4) Launch pi unless already running
if pi_running; then
  echo "reusing existing pi session: $session"
else
  tmux send-keys -t "$session" "pi '$prompt'" Enter
  echo "sent pi prompt"
fi

# 5) Verify pi up (poll up to 15s)
for _ in $(seq 1 15); do
  if pi_running; then
    echo "pi confirmed running"
    echo "SESSION=$session"
    break
  fi
  sleep 1
done

if ! pi_running; then
  echo "WARN: pi not detected in $session — attach + check manually" >&2
  echo "SESSION=$session"
  echo "NOTE: handoff failed — parent agent left alive" >&2
  exit 1
fi

# 6) Handoff report — stdout + durable file (parent may quit before render)
report_file="${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt"
mkdir -p "$(dirname "$report_file")"
{
  echo ""
  echo "=== Linear ticket handoff $(date '+%Y-%m-%d %H:%M:%S') ==="
  echo "Issue:      $issue"
  echo "URL:        $url"
  echo "Branch:     $branch"
  echo "Worktree:   $worktree_path"
  echo "Tmux:       $session"
  echo "Attach:     sesh connect $worktree_path   |   tmux attach -t $session"
  echo "Report:     $report_file"
} | tee -a "$report_file"

# 7) Deferred parent exit — script returns first, then /quit
if schedule_parent_quit; then
  exit 0
fi

echo "handoff succeeded; session: $session; report: $report_file" >&2
exit 0
