#!/usr/bin/env bash
# Watch a wave by branch name, not by pull request number (reference/lane-watch.md).
#
# Start it in the same turn as the first lane spawn. A branch with no pull
# request yet prints PR_OPEN when the request appears, so the watch starts
# before the work needs it.
#
# The script owns its own deadline, so it exits before the ctx_bg job limit.
# A job that dies at exit 124 means the loop outran timeout_ms: pass a window
# below the job limit minus a 120 s margin.
#
# Usage:
#   watch-wave.sh <branch> [branch ...] [--window <sec>] [--interval <sec>]
#   watch-wave.sh <branch> --all-merged    stop once every branch merged
# Default: window 3000 s, interval 45 s.
#
# Lines: PR_OPEN, CLEAN, STATE, CIFAIL, MERGED, CLOSED, DONE, TIMEOUT, ERROR.
# Every state exits 0, because a merge is a result and not a fault.
#
# One job per wave is the default. Split into one job per pull request when the
# requests live in different phases. Read reference/lane-watch.md.

set -uo pipefail

WINDOW=3000
INTERVAL=45
ALL_MERGED=0
BRANCHES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --window)
      WINDOW="${2:?--window needs seconds}"
      shift 2
      ;;
    --interval)
      INTERVAL="${2:?--interval needs seconds}"
      shift 2
      ;;
    --all-merged)
      ALL_MERGED=1
      shift
      ;;
    *)
      BRANCHES+=("$1")
      shift
      ;;
  esac
done

if [ "${#BRANCHES[@]}" -eq 0 ]; then
  echo "ERROR no branch given"
  exit 1
fi

command -v gh >/dev/null || {
  echo "ERROR no gh"
  exit 1
}

STATE_DIR="/tmp/agent-tmp/watch-wave"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/state"
: >"$STATE"

# The loop stops 120 s before the window, so the job never reaches its limit.
# A short window keeps at least 5 s, so a test run still reads once.
SPAN=$((WINDOW - 120))
[ "$SPAN" -lt 5 ] && SPAN=5
END=$((SECONDS + SPAN))

probe() {
  local branch="$1"
  gh pr list --head "$branch" --state all --json number,state,mergeStateStatus,statusCheckRollup 2>/dev/null |
    jq -r --arg b "$branch" '
      if length == 0 then "\($b) NOPR - -"
      else
        (.[0]) as $p |
        ($p.statusCheckRollup // [] | map(select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .conclusion == "CANCELLED")) | length) as $bad |
        "\($b) \($p.number) \($p.state) \($p.mergeStateStatus) \($bad)"
      end'
}

while [ "$SECONDS" -lt "$END" ]; do
  for branch in "${BRANCHES[@]}"; do
    line=$(probe "$branch")
    [ -z "$line" ] && {
      echo "ERROR cannot read $branch"
      exit 1
    }
    key=$(printf '%s' "$line" | awk '{print $1}')
    number=$(printf '%s' "$line" | awk '{print $2}')
    state=$(printf '%s' "$line" | awk '{print $3}')
    merge=$(printf '%s' "$line" | awk '{print $4}')
    bad=$(printf '%s' "$line" | awk '{print $5}')

    prev=$(grep -F "$key " "$STATE" 2>/dev/null | tail -1 | awk '{print $2, $3, $4, $5}')
    if [ "$prev" != "$number $state $merge $bad" ]; then
      grep -vF "$key " "$STATE" >"$STATE.tmp" 2>/dev/null
      mv "$STATE.tmp" "$STATE"
      printf '%s %s %s %s %s\n' "$key" "$number" "$state" "$merge" "$bad" >>"$STATE"

      if [ "$number" = "-" ] || [ "$number" = "NOPR" ]; then
        :
      elif [ "$prev" = "" ] || [ "$(printf '%s' "$prev" | awk '{print $1}')" = "-" ]; then
        echo "PR_OPEN $number $key"
      fi

      case "$state" in
        MERGED) echo "MERGED $number $key" ;;
        CLOSED) echo "CLOSED $number $key" ;;
      esac

      if [ "$bad" != "0" ] && [ "$bad" != "-" ]; then
        echo "CIFAIL $number $key"
      fi

      case "$merge" in
        CLEAN) echo "CLEAN $number $key" ;;
        DIRTY | BEHIND | BLOCKED) echo "STATE $number $key $merge" ;;
      esac
    fi
  done

  if [ "$ALL_MERGED" -eq 1 ]; then
    open=0
    for branch in "${BRANCHES[@]}"; do
      line=$(probe "$branch")
      state=$(printf '%s' "$line" | awk '{print $3}')
      case "$state" in
        MERGED | CLOSED | -) ;;
        *) open=$((open + 1)) ;;
      esac
    done
    if [ "$open" -eq 0 ]; then
      echo "DONE every branch merged or closed"
      exit 0
    fi
  fi

  sleep "$INTERVAL"
done

echo "TIMEOUT window ${WINDOW}s: read the three gate states by hand"
