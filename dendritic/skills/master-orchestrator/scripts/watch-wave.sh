#!/usr/bin/env bash
# Watch a pull request by branch name (reference/lane-watch.md).
#
# Start it on lane spawn, before the pull request exists. A branch with no
# request yet prints nothing until the request appears, then PR_OPEN.
#
# Every run reads a baseline and prints it. A conflict or a red check that
# already exists then wakes you at start, not one interval later.
#
# Usage:
#   watch-wave.sh <branch> [branch ...] [--window <sec>] [--interval <sec>]
#   watch-wave.sh <branch> --all-merged    stop once every branch landed
# Default: window 3000 s, interval 45 s.
#
# Lines: PR_OPEN, CONFLICT, BEHIND, BLOCKED, CIFAIL, CLEAN, PENDING, MERGED,
# CLOSED, FOUND, CR_REVIEW, REVIEW, DONE, TIMEOUT, ERROR. Every state exits 0,
# because a merge is a result.
#
# The job ends as soon as a line needs you: a conflict, a red check, a new
# unresolved review thread, a new bot review that carries no thread, a review
# that asks for changes, a merge, a close, or DONE. A finished job always wakes
# the orchestrator, so a fault that exists before the start still reaches it.
# Restart the job after you act.
#
# One job per branch is the default, so the jobs widget shows one row each.

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

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
OWNER=${SLUG%%/*}
REPO_NAME=${SLUG##*/}
[ -n "$OWNER" ] || {
  echo "ERROR no GitHub repo"
  exit 1
}

# A state file holds this run alone, so every start prints its baseline.
STATE_DIR="/tmp/agent-tmp/watch-wave"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/state-$$"
: >"$STATE"
trap 'rm -f "$STATE"' EXIT

SPAN=$((WINDOW - 120))
[ "$SPAN" -lt 5 ] && SPAN=5
END=$((SECONDS + SPAN))

# One line per branch: branch, number, state, mergeable, mergeStateStatus, bad checks.
probe() {
  local branch="$1"
  gh pr list --head "$branch" --state all \
    --json number,state,mergeable,mergeStateStatus,statusCheckRollup 2>/dev/null |
    jq -r --arg b "$branch" '
      if length == 0 then "\($b)|-|-|-|-|-"
      else
        (.[0]) as $p |
        ($p.statusCheckRollup // []
          | map(select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT"
                       or .conclusion == "CANCELLED" or .conclusion == "ACTION_REQUIRED"))
          | length) as $bad |
        "\($b)|\($p.number)|\($p.state)|\($p.mergeable // "-")|\($p.mergeStateStatus // "-")|\($bad)"
      end'
}

# One line per pull request: unresolved threads, review decision, first thread site,
# then the newest review author, time and state.
probe_reviews() {
  local number="$1"
  gh api graphql -f query="
    query { repository(owner: \"$OWNER\", name: \"$REPO_NAME\") {
      pullRequest(number: $number) {
        reviewDecision
        reviewThreads(first: 100) { nodes { isResolved isOutdated path line } }
        reviews(last: 1) { nodes { author { login } createdAt state } }
      } } }" 2>/dev/null |
    jq -r '
      .data.repository.pullRequest as $p |
      ($p.reviewThreads.nodes | map(select((.isResolved | not) and (.isOutdated | not)))) as $open |
      ($p.reviews.nodes[0]) as $r |
      "\($open | length)|\($p.reviewDecision // "-")|\($open[0].path // "-"):\($open[0].line // 0)|\($r.author.login // "-")|\($r.createdAt // "-")|\($r.state // "-")"'
}

FOUND_FAULT=0

report() {
  local line="$1"
  local branch number state mergeable merge bad
  branch=$(printf '%s' "$line" | cut -d'|' -f1)
  number=$(printf '%s' "$line" | cut -d'|' -f2)
  state=$(printf '%s' "$line" | cut -d'|' -f3)
  mergeable=$(printf '%s' "$line" | cut -d'|' -f4)
  merge=$(printf '%s' "$line" | cut -d'|' -f5)
  bad=$(printf '%s' "$line" | cut -d'|' -f6)

  local threads="-" decision="-" site="-" rv
  local rev_author="-" rev_at="-" rev_state="-"
  if [ "$number" != "-" ]; then
    rv=$(probe_reviews "$number")
    if [ -n "$rv" ]; then
      threads=$(printf '%s' "$rv" | cut -d'|' -f1)
      decision=$(printf '%s' "$rv" | cut -d'|' -f2)
      site=$(printf '%s' "$rv" | cut -d'|' -f3)
      rev_author=$(printf '%s' "$rv" | cut -d'|' -f4)
      rev_at=$(printf '%s' "$rv" | cut -d'|' -f5)
      rev_state=$(printf '%s' "$rv" | cut -d'|' -f6)
    fi
  fi

  local key prev now prev_threads prev_decision prev_rev
  key=$(printf '%s' "$branch" | tr '/' '_')
  prev=$(grep -F "$key|" "$STATE" 2>/dev/null | tail -1)
  prev_threads=$(printf '%s' "$prev" | cut -d'|' -f7)
  prev_decision=$(printf '%s' "$prev" | cut -d'|' -f8)
  prev_rev=$(printf '%s' "$prev" | cut -d'|' -f10)
  now="$key|$number|$state|$mergeable|$merge|$bad|$threads|$decision|$site|$rev_at"
  [ "$prev" = "$now" ] && return 0
  grep -vF "$key|" "$STATE" >"$STATE.tmp" 2>/dev/null
  mv "$STATE.tmp" "$STATE"
  printf '%s\n' "$now" >>"$STATE"

  # No request yet: say nothing, and keep watching.
  [ "$number" = "-" ] && return 0

  if [ -z "$prev" ]; then
    echo "PR_OPEN $number $branch"
  fi

  case "$state" in
    MERGED)
      echo "MERGED $number $branch"
      [ "$ALL_MERGED" -eq 0 ] && FOUND_FAULT=1
      return 0
      ;;
    CLOSED)
      echo "CLOSED $number $branch"
      FOUND_FAULT=1
      return 0
      ;;
  esac

  # A conflict reads DIRTY on mergeStateStatus, or CONFLICTING on mergeable.
  if [ "$mergeable" = "CONFLICTING" ] || [ "$merge" = "DIRTY" ]; then
    echo "CONFLICT $number $branch ($mergeable/$merge)"
    FOUND_FAULT=1
  elif [ "$merge" = "BEHIND" ]; then
    echo "BEHIND $number $branch"
    FOUND_FAULT=1
  elif [ "$merge" = "BLOCKED" ]; then
    echo "BLOCKED $number $branch"
    FOUND_FAULT=1
  fi

  if [ "$bad" != "0" ] && [ "$bad" != "-" ]; then
    echo "CIFAIL $number $branch ($bad checks)"
    FOUND_FAULT=1
  fi

  # A review thread that nobody resolved, or a review that asks for changes.
  if [ "$threads" != "-" ] && [ "$threads" != "0" ] && [ "$threads" != "$prev_threads" ]; then
    echo "FOUND $number $branch ($threads threads, first $site)"
    FOUND_FAULT=1
    return 0
  fi

  if [ "$decision" = "CHANGES_REQUESTED" ] && [ "$decision" != "$prev_decision" ]; then
    echo "REVIEW $number $branch (changes requested)"
    FOUND_FAULT=1
    return 0
  fi

  # A bot review wakes you even when it posts no inline thread. Its summary body
  # holds findings that no thread carries, so read the body after this line.
  case "$rev_author" in
    *coderabbit*)
      if [ "$rev_at" != "-" ] && [ "$rev_at" != "$prev_rev" ] && [ -n "$prev" ]; then
        echo "CR_REVIEW $number $branch ($rev_state at $rev_at: read the review body)"
        FOUND_FAULT=1
        return 0
      fi
      ;;
  esac

  if [ "$merge" = "CLEAN" ]; then
    echo "CLEAN $number $branch"
  elif [ "$merge" = "UNSTABLE" ]; then
    echo "PENDING $number $branch"
  fi
}

while [ "$SECONDS" -lt "$END" ]; do
  FOUND_FAULT=0
  for branch in "${BRANCHES[@]}"; do
    line=$(probe "$branch")
    if [ -z "$line" ]; then
      echo "ERROR cannot read $branch"
      exit 1
    fi
    report "$line"
  done

  # A line that needs you ends the job, so the wake is never lost.
  [ "$FOUND_FAULT" -eq 1 ] && exit 0

  if [ "$ALL_MERGED" -eq 1 ]; then
    open=0
    for branch in "${BRANCHES[@]}"; do
      state=$(probe "$branch" | cut -d'|' -f3)
      case "$state" in
        MERGED | CLOSED | -) ;;\
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
