#!/usr/bin/env bash
# Worktree prep for peer spawns. No pi, no tmux, no session naming.
#
# Usage: prepare-worktree.sh [--existing] <repo_cwd> <branch>
#
#   --existing   branch already exists → `wt switch <branch>`
#                default → `wt switch -b @ -c <branch>`
#
# Prints WORKTREE=<absolute path>. Non-zero on wt failure or unparsable path.
set -euo pipefail

usage_error() {
  echo "ERROR: $*" >&2
  exit 2
}

existing=0
while [ $# -gt 0 ]; do
  case "$1" in
    --existing) existing=1; shift ;;
    --) shift; break ;;
    -*) usage_error "unknown flag: $1" ;;
    *) break ;;
  esac
done

repo_cwd="${1:-}"
branch="${2:-}"
[ -n "$repo_cwd" ] || usage_error "repo_cwd required"
[ -n "$branch" ] || usage_error "branch required"
[ -d "$repo_cwd" ] || usage_error "repo_cwd not a directory: $repo_cwd"
command -v wt >/dev/null || usage_error "wt not on PATH"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ "$existing" = 1 ]; then
  wt_output=$(cd "$repo_cwd" && wt switch "$branch" 2>&1) || {
    echo "ERROR: wt switch failed" >&2
    printf '%s\n' "$wt_output" >&2
    exit 1
  }
else
  wt_output=$(cd "$repo_cwd" && wt switch -b @ -c "$branch" 2>&1) || {
    echo "ERROR: wt switch -b @ -c failed" >&2
    printf '%s\n' "$wt_output" >&2
    exit 1
  }
fi

worktree=$(printf '%s\n' "$wt_output" | bash "$script_dir/parse-worktree-path.sh" 2>/dev/null || true)
if [ -z "$worktree" ]; then
  echo "ERROR: could not parse worktree path from wt output" >&2
  printf '%s\n' "$wt_output" >&2
  exit 1
fi
if [ ! -d "$worktree" ]; then
  echo "ERROR: parsed worktree path does not exist: $worktree" >&2
  exit 1
fi

echo "WORKTREE=$worktree"
