#!/bin/sh
# Full submodule sync: fetch upstream refs in parallel, then checkout recorded SHAs.
# The post-merge hook calls this script in the background. Run it by hand after a clone.
set -eu

cd "$(git rev-parse --show-toplevel)"
root=$(pwd)
jobs=${SUBMODULE_REFRESH_JOBS:-8}

# One run at a time. A second pull must not race the first refresh.
lock="$root/.git/submodule-refresh.lock"
if ! mkdir "$lock" 2>/dev/null; then
  echo "submodule-refresh: run in progress, skip" >&2
  exit 0
fi
trap 'rmdir "$lock" 2>/dev/null || true' EXIT INT TERM HUP

git submodule sync --recursive

paths="$root/.git/submodule-refresh.paths"
git submodule foreach --recursive --quiet 'if [ -d "$displaypath" ]; then printf "%s\n" "$displaypath"; fi' >"$paths"
if [ -s "$paths" ]; then
  xargs -P "$jobs" -n 1 sh -c 'git -C "$1" fetch --prune --quiet' _ <"$paths" ||
    echo "submodule-refresh: some fetches failed" >&2
fi
rm -f "$paths"

git submodule update --init --recursive
