#!/usr/bin/env bash
# Extract Linear issue id from git branch name.
# Usage: parse-issue-id.sh <branch>
# Example: mattmak/prd-239-foo → PRD-239
set -euo pipefail

branch="${1:?branch required}"
slug="${branch##*/}"

if [[ "$slug" =~ ^([a-z]+)-([0-9]+) ]]; then
  team="${BASH_REMATCH[1]}"
  num="${BASH_REMATCH[2]}"
  printf '%s-%s\n' "$(printf '%s' "$team" | tr '[:lower:]' '[:upper:]')" "$num"
  exit 0
fi

echo "error: no issue id in branch slug: $slug" >&2
exit 1
