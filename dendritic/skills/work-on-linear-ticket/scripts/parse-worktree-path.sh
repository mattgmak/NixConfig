#!/usr/bin/env bash
# Parse absolute worktree path from wt switch stdout/stderr.
# Usage: parse-worktree-path.sh [file]   (stdin if no file)
set -euo pipefail

if [ $# -gt 0 ]; then
  input=$(cat "$1")
else
  input=$(cat)
fi

# Primary: "worktree @ /abs/path"
if [[ "$input" =~ worktree[[:space:]]@([[:space:]]+)(/[^[:space:]]+) ]]; then
  printf '%s\n' "${BASH_REMATCH[2]}"
  exit 0
fi

# Fallback: trailing "@ /abs/path"
if [[ "$input" =~ @[[:space:]]+(/[^[:space:]]+)[[:space:]]*$ ]]; then
  printf '%s\n' "${BASH_REMATCH[1]}"
  exit 0
fi

echo "error: could not parse worktree path from wt output" >&2
exit 1
