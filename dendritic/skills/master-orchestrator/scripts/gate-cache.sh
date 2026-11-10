#!/usr/bin/env bash
# One gate run per head, then read the cache (reference/agent-loop.md).
#
# The wave ran 39 gate runs for one ticket. Each head needs one run, and every
# later reader reads the cache.
#
# Usage:
#   gate-cache.sh                 run the gates at this head, or print the cache
#   gate-cache.sh --read          print the cache, exit 1 when empty
#   gate-cache.sh --force         drop the cache and run again
#   gate-cache.sh --test "<cmd>"  use another test command (default: app tests)
#
# Set BASE_REF to the pull request base, for example:
#   BASE_REF=origin/mattmak/meal-plan-agent gate-cache.sh
# A wrong base gives a wide file set, and the biome step then skips.
#
# Cache: /tmp/agent-tmp/<project>/gates/<head>.json

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "FAIL: run this in a git worktree"
  exit 1
}

PROJECT=$(basename "$ROOT")
HEAD=$(git -C "$ROOT" rev-parse --short HEAD)
DIR="/tmp/agent-tmp/$PROJECT/gates"
FILE="$DIR/$HEAD.json"
TEST_CMD="pnpm --filter tcm-app test"

MODE="run"
case "${1:-}" in
  --read) MODE="read" ;;
  --force) MODE="force" ;;
  --test)
    MODE="run"
    TEST_CMD="${2:?gate-cache.sh --test needs a command}"
    ;;
  "") ;;
  *)
    echo "FAIL: unknown option $1"
    exit 2
    ;;
esac

print_cache() {
  jq -r 'to_entries[] | "\(.key) \(.value)"' "$FILE"
}

if [ "$MODE" = "read" ]; then
  [ -f "$FILE" ] || {
    echo "MISS $HEAD: run gate-cache.sh"
    exit 1
  }
  echo "CACHED $HEAD"
  print_cache
  exit 0
fi

if [ "$MODE" = "force" ]; then
  rm -f "$FILE"
fi

if [ -f "$FILE" ]; then
  echo "CACHED $HEAD"
  print_cache
  echo "head unchanged: no gate ran again"
  exit 0
fi

mkdir -p "$DIR"
TMP="$FILE.part"
: >"$TMP"

run_gate() {
  local name="$1"
  shift
  "$@" >/tmp/agent-tmp-gate.log 2>&1
  local code=$?
  printf '%s %s\n' "$name" "$code" >>"$TMP"
  printf '%s %s\n' "$name" "$code"
  return 0
}

echo "RUN $HEAD"
run_gate check-types pnpm check-types

changed=$(git -C "$ROOT" diff --name-only "$(git -C "$ROOT" merge-base HEAD "${BASE_REF:-origin/HEAD}" 2>/dev/null || echo HEAD~1)" -- 2>/dev/null)
count=$(printf '%s\n' "$changed" | grep -c . || true)
if [ "$count" -eq 0 ]; then
  printf 'biome skip-empty\n' >>"$TMP"
  printf 'biome skip-empty\n'
elif [ "$count" -gt 50 ]; then
  # A wide set means the base ref is wrong. Never format the whole tree.
  printf 'biome skip-wide(%s)\n' "$count" >>"$TMP"
  printf 'biome skip-wide(%s)\n' "$count"
else
  # Read-only: this script never rewrites a file. The lane runs --write itself.
  # shellcheck disable=SC2086
  run_gate biome pnpm biome check $changed
fi

# shellcheck disable=SC2086
run_gate tests $TEST_CMD

jq -Rn '[inputs | split(" ") | {(.[0]): (.[1] | tonumber? // .[1])}] | add' <"$TMP" >"$FILE"
rm -f "$TMP"

echo "CACHED $HEAD"
print_cache
