#!/usr/bin/env bash
# Root the flake input source trees of a lock file, because gc-collect-garbage
# deletes them and the next eval refetches them.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
flake_dir="${1:-$(dirname -- "$script_dir")}"
root_dir="${HOME:?}/.local/state/flake-sources"

if [ ! -f "${flake_dir}/flake.nix" ]; then
  printf 'error: %s holds no flake.nix\n' "$flake_dir" >&2
  exit 1
fi

archive_err=$(mktemp)
build_log=$(mktemp)
trap 'rm -f "$archive_err" "$build_log"' EXIT

cd "$flake_dir"
if ! archive_json=$(nix flake archive --json 2>"$archive_err"); then
  printf 'error: nix flake archive failed in %s\n' "$flake_dir" >&2
  cat "$archive_err" >&2
  exit 1
fi

parse_py='
import json
import sys

def walk(node, found):
    if isinstance(node, dict):
        value = node.get("path")
        if isinstance(value, str):
            found.append(value)
        for child in node.values():
            walk(child, found)
    elif isinstance(node, list):
        for child in node:
            walk(child, found)

found = []
walk(json.load(sys.stdin), found)
seen = set()
for item in found:
    if item not in seen:
        seen.add(item)
        sys.stdout.write(item + "\n")
'

if ! path_list=$(printf '%s' "$archive_json" | python3 -c "$parse_py"); then
  printf 'error: cannot parse the nix flake archive output\n' >&2
  exit 1
fi

if [ -z "$path_list" ]; then
  printf 'error: nix flake archive reported no input path\n' >&2
  exit 1
fi

mkdir -p "$root_dir"

for link in "$root_dir"/flake-src-*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link")
  keep=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ "$path" = "$target" ]; then
      keep=1
      break
    fi
  done <<<"$path_list"
  if [ "$keep" -eq 0 ]; then
    rm -f "$link"
    printf 'pruned stale root %s\n' "$link"
  fi
done

index=0
total_mb=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  link="$root_dir/flake-src-$index"
  # An unprivileged out-link is a root the daemon owns. builtins.storePath
  # only references the path, so nothing is added or built.
  if ! nix build --impure --out-link "$link" \
    --expr "builtins.storePath \"$path\"" >"$build_log" 2>&1; then
    printf 'error: cannot root %s\n' "$path" >&2
    cat "$build_log" >&2
    exit 1
  fi
  if grep -Eq 'downloading|copying path|fetching' "$build_log"; then
    printf 'error: rooting %s touched the network or the store\n' "$path" >&2
    cat "$build_log" >&2
    exit 1
  fi
  size_mb=$(du -sm "$path" | cut -f1)
  total_mb=$((total_mb + size_mb))
  printf '%8s MB  %s\n' "$size_mb" "$path"
  index=$((index + 1))
done <<<"$path_list"

printf 'rooted %d flake source tree(s), %d MB, roots in %s\n' "$index" "$total_mb" "$root_dir"
