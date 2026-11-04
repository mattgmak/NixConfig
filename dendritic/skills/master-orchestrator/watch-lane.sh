#!/usr/bin/env bash
# Watch one open pull request for the states that need the orchestrator.
#
# Usage: watch-lane.sh <pr> [owner/repo] [timeout-seconds] [interval-seconds]
#
# Exit 0 = a state arrived. The first line names it: MERGED, CLOSED, FOUND,
#          CONFLICT, RATE_LIMIT or TIMEOUT.
# Exit 1 = ERROR. The state could not be read, so read the pull request by hand.
#
# A landed pull request exits 0, because a merge is the result and not a fault.
# A review limit prints one RATE_LIMIT line and the watch continues, because a
# merge or a conflict still matters while CodeRabbit is quiet.
#
# Run it with ctx_bg and wake_on '^(FOUND|CONFLICT|MERGED|CLOSED|RATE_LIMIT) '.
# Never poll by hand.

set -uo pipefail

PR="${1:?usage: watch-lane.sh <pr> [owner/repo] [timeout] [interval]}"
REPO="${2:-DrPOM-Medical/tcm}"
DEADLINE_SECONDS="${3:-7200}"
INTERVAL="${4:-60}"
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

list_threads | cut -f1 | sed '/^$/d' | sort >"$SEEN_FILE"

echo "STANDING $(wc -l <"$SEEN_FILE" | tr -d ' ') unresolved thread(s) at start on pr=$PR"

deadline=$(( $(date +%s) + DEADLINE_SECONDS ))
limited=0
blind=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  read -r state head < <(gh pr view "$PR" --repo "$REPO" --json state,headRefOid \
    --jq '"\(.state) \(.headRefOid[0:7])"' 2>/dev/null)
  if [ -z "${state:-}" ]; then
    blind=$(( blind + 1 ))
    if [ "$blind" -ge 5 ]; then
      echo "ERROR cannot read pr=$PR repo=$REPO after 5 tries"
      exit 1
    fi
    sleep "$INTERVAL"
    continue
  fi
  blind=0
  case "$state" in
    MERGED) echo "MERGED pr=$PR head=$head"; exit 0 ;;
    CLOSED) echo "CLOSED pr=$PR head=$head"; exit 0 ;;
  esac

  mergeable="$(gh pr view "$PR" --repo "$REPO" --json mergeable --jq '.mergeable' 2>/dev/null)"
  if [ "$mergeable" = "CONFLICTING" ]; then
    echo "CONFLICT pr=$PR head=$head mergeable=CONFLICTING"
    exit 0
  fi

  current="$(list_threads)"
  ids="$(printf '%s\n' "$current" | cut -f1 | sed '/^$/d' | sort)"
  new_ids="$(comm -13 "$SEEN_FILE" <(printf '%s\n' "$ids"))"

  if [ -n "$new_ids" ]; then
    echo "FOUND $(printf '%s\n' "$new_ids" | wc -l | tr -d ' ') new CodeRabbit thread(s) on pr=$PR"
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      printf '%s\n' "$current" | awk -F'\t' -v want="$id" '$1 == want { print "=== " $2; print $3; print "" }'
      echo "$id" >>"$SEEN_FILE"
    done <<<"$new_ids"
    sort -o "$SEEN_FILE" "$SEEN_FILE"
    exit 0
  fi

  if rate_limited; then
    if [ "$limited" -eq 0 ]; then
      echo "RATE_LIMIT CodeRabbit reports a review limit on pr=$PR"
      limited=1
    fi
  else
    limited=0
  fi

  sleep "$INTERVAL"
done

if [ "$limited" -eq 1 ]; then
  echo "RATE_LIMIT pr=$PR stayed rate-limited for ${DEADLINE_SECONDS}s"
  exit 0
fi

echo "TIMEOUT no new state on pr=$PR after ${DEADLINE_SECONDS}s"
exit 0
