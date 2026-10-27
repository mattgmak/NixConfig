#!/usr/bin/env bash
# Root the flake input source trees of a lock file, because gc-collect-garbage
# deletes them and the next eval refetches them.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
flake_dir="${1:-$(dirname -- "$script_dir")}"
root_dir="${HOME:?}/.local/state/flake-sources"
cache="$root_dir/paths"
stamp_file="$root_dir/paths.stamp"
sizes_file="$root_dir/paths.sizes"

if [ ! -f "${flake_dir}/flake.nix" ]; then
  printf 'error: %s holds no flake.nix\n' "$flake_dir" >&2
  exit 1
fi

mkdir -p "$root_dir"

# The archive call evaluates the flake, about 8s here. The lock and the nix
# version decide its result, so a matching stamp reuses the cached path list.
stamp=$( { cat "${flake_dir}/flake.lock"; nix --version; } | sha256sum | cut -d' ' -f1 )

if [ ! -s "$cache" ] || [ "$(cat "$stamp_file" 2>/dev/null)" != "$stamp" ]; then
  archive_err=$(mktemp)
  trap 'rm -f "$archive_err"' EXIT
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

  printf '%s\n' "$path_list" >"$cache"
  printf '%s\n' "$stamp" >"$stamp_file"
  rm -f "$sizes_file"
fi

# One metadata query beats a du walk over 5 GB of source trees.
if [ ! -s "$sizes_file" ]; then
  # shellcheck disable=SC2046
  nix path-info --size --json $(cat "$cache") | python3 -c '
import json
import sys

data = json.load(sys.stdin)
items = data.items() if isinstance(data, dict) else ((e["path"], e) for e in data)
for path, entry in items:
    print(path, (entry["narSize"] + 1048575) // 1048576)
' >"$sizes_file"
fi

path_list=$(cat "$cache")

pruned=0
for link in "$root_dir"/flake-src-*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link")
  if ! printf '%s\n' "$path_list" | grep -Fxq "$target"; then
    rm -f "$link"
    pruned=$((pruned + 1))
    printf 'pruned stale root %s\n' "$link"
  fi
done

index=0
total_mb=0
changed=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  link="$root_dir/flake-src-$index"
  # An unprivileged out-link is a root the daemon owns. --add-root only
  # registers the path, so it neither builds nor fetches, and it skips the
  # nix evaluation that `nix build --expr` pays per tree.
  if [ "$(readlink "$link" 2>/dev/null)" != "$path" ]; then
    if ! nix-store --add-root "$link" -r "$path" >/dev/null; then
      printf 'error: cannot root %s\n' "$path" >&2
      exit 1
    fi
    changed=$((changed + 1))
  fi
  size_mb=$(grep -Fm1 "$path " "$sizes_file" | cut -d' ' -f2 || printf '0')
  total_mb=$((total_mb + size_mb))
  index=$((index + 1))
done <<<"$path_list"

printf 'rooted %d flake source tree(s), %d MB, %d new root(s), %d pruned, roots in %s\n' \
  "$index" "$total_mb" "$changed" "$pruned" "$root_dir"
