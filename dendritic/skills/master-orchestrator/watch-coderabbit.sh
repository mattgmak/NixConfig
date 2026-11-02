#!/usr/bin/env bash
# Watch a pull request for new CodeRabbit review threads.
#
# Usage: watch-coderabbit.sh <pr> [owner/repo] [timeout-seconds]
#
# Exit 0 = FOUND new unresolved CodeRabbit threads, printed below the marker.
# Exit 1 = TIMEOUT, no new thread.
# Exit 2 = RATE_LIMIT, CodeRabbit stopped reviewing.
# Exit 3 = CLOSED, the pull request merged or closed.
#
# Run it with ctx_bg. Never poll by hand.

set -uo pipefail

PR="${1:?usage: watch-coderabbit.sh <pr> [owner/repo] [timeout-seconds]}"
REPO="${2:-DrPOM-Medical/tcm}"
DEADLINE_SECONDS="${3:-1200}"
INTERVAL="${4:-45}"
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

SEEN_FILE="$(mktemp)"
trap 'rm -f "$SEEN_FILE"' EXIT

list_threads() {
  gh api graphql \
    -f query="query{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$PR){reviewThreads(first:100){nodes{id isResolved path line comments(first:1){nodes{author{login} body}}}}}}}" \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[]
          | select(.isResolved == false)
          | select(.comments.nodes[0].author.login == "coderabbitai")
          | [.id, (.path + ":" + (.line // 0 | tostring)), (.comments.nodes[0].body[0:1200] | gsub("\\s+"; " "))]
          | @tsv'
}

rate_limited() {
  gh pr view "$PR" --repo "$REPO" --json comments \
    --jq '.comments[] | select(.author.login == "coderabbitai") | .body' 2>/dev/null \
    | rg -qi 'rate limit|review limit|limit reached|next review in'
}

# Seed the seen set so only threads that arrive after this call count.
list_threads | cut -f1 | sed '/^$/d' | sort >"$SEEN_FILE"

echo "WATCH start pr=$PR repo=$REPO timeout=${DEADLINE_SECONDS}s seeded=$(wc -l <"$SEEN_FILE" | tr -d ' ')"

deadline=$(( $(date +%s) + DEADLINE_SECONDS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  state="$(gh pr view "$PR" --repo "$REPO" --json state --jq '.state' 2>/dev/null)"
  case "$state" in
    MERGED|CLOSED) echo "CLOSED state=$state"; exit 3 ;;
  esac

  current="$(list_threads)"
  ids="$(printf '%s\n' "$current" | cut -f1 | sed '/^$/d' | sort)"
  new_ids="$(comm -13 "$SEEN_FILE" <(printf '%s\n' "$ids"))"

  if [ -n "$new_ids" ]; then
    echo "FOUND $(printf '%s\n' "$new_ids" | wc -l | tr -d ' ') new CodeRabbit thread(s)"
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      printf '%s\n' "$current" | awk -F'\t' -v want="$id" '$1 == want { print "=== " $2; print $3; print "" }'
      echo "$id" >>"$SEEN_FILE"
    done <<<"$new_ids"
    sort -o "$SEEN_FILE" "$SEEN_FILE"
    exit 0
  fi

  if rate_limited; then
    echo "RATE_LIMIT CodeRabbit reports a review limit on pr=$PR"
    exit 2
  fi

  sleep "$INTERVAL"
done

echo "TIMEOUT no new CodeRabbit thread on pr=$PR after ${DEADLINE_SECONDS}s"
exit 1
