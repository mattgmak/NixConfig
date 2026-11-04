#!/usr/bin/env bash
# Watch several open pull requests with one job.
#
# Usage: watch-lanes.sh [owner/repo] [timeout-seconds] [interval-seconds] <pr>...
#
# Exit 0 = a state arrived. The first line names it and the pull request:
#          MERGED, CLOSED, CONFLICT, FOUND, RATE_LIMIT or TIMEOUT.
# Exit 1 = ERROR, a pull request could not be read 5 times in a row.
#
# One job holds every lane, so the id does not churn. A landed pull request
# exits 0, because a merge is the result and not a fault.
#
# Run it with ctx_bg and wake_on '^(FOUND|CONFLICT|MERGED|CLOSED) '.

set -uo pipefail

REPO="${1:-DrPOM-Medical/tcm}"
DEADLINE_SECONDS="${2:-3000}"
INTERVAL="${3:-60}"
shift 3 2>/dev/null || true
PRS=("$@")

if [ "${#PRS[@]}" -eq 0 ]; then
  echo "ERROR usage: watch-lanes.sh [owner/repo] [timeout] [interval] <pr>..."
  exit 1
fi

OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
SEEN_DIR="$(mktemp -d)"
trap 'rm -rf "$SEEN_DIR"' EXIT

list_threads() {
  gh api graphql \
    -f query="query{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$1){reviewThreads(first:100){nodes{id isResolved path line comments(first:1){nodes{author{login} body}}}}}}}" \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[]
          | select(.isResolved == false)
          | select(.comments.nodes[0].author.login == "coderabbitai")
          | [.id, (.path + ":" + (.line // 0 | tostring)), (.comments.nodes[0].body[0:1200] | gsub("\\s+"; " "))]
          | @tsv'
}

list_checks() {
  gh pr checks "$1" --repo "$REPO" --json name,bucket 2>/dev/null \
    | jq -r '.[] | "\(.name)\t\(.bucket)"' | sort
}

at_start=()
for pr in "${PRS[@]}"; do
  list_threads "$pr" | cut -f1 | sed '/^$/d' | sort >"$SEEN_DIR/$pr"
  echo "STANDING pr=$pr $(wc -l <"$SEEN_DIR/$pr" | tr -d ' ') unresolved thread(s)"
  list_checks "$pr" >"$SEEN_DIR/checks-$pr"
  if rg -q '\tfail$' "$SEEN_DIR/checks-$pr"; then
    at_start+=("RED_AT_START pr=$pr $(awk -F'\t' '$2=="fail"{print $1}' "$SEEN_DIR/checks-$pr" | tr '\n' ' ')")
  fi
done

for line in "${at_start[@]:-}"; do
  [ -n "$line" ] && echo "$line"
done

limited=0
blind=0
deadline=$(( $(date +%s) + DEADLINE_SECONDS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  for pr in "${PRS[@]}"; do
    read -r state head < <(gh pr view "$pr" --repo "$REPO" --json state,headRefOid \
      --jq '"\(.state) \(.headRefOid[0:7])"' 2>/dev/null)
    if [ -z "${state:-}" ]; then
      blind=$(( blind + 1 ))
      if [ "$blind" -ge 5 ]; then
        echo "ERROR cannot read pr=$pr repo=$REPO after 5 tries"
        exit 1
      fi
      continue
    fi
    blind=0

    case "$state" in
      MERGED) echo "MERGED pr=$pr head=$head"; exit 0 ;;
      CLOSED) echo "CLOSED pr=$pr head=$head"; exit 0 ;;
    esac

    mergeable="$(gh pr view "$pr" --repo "$REPO" --json mergeable --jq '.mergeable' 2>/dev/null)"
    if [ "$mergeable" = "CONFLICTING" ]; then
      echo "CONFLICT pr=$pr head=$head mergeable=CONFLICTING"
      exit 0
    fi

    current="$(list_checks "$pr")"
    if printf '%s\n' "$current" | rg -q '\tfail$'; then
      if ! cmp -s <(printf '%s\n' "$current") "$SEEN_DIR/checks-$pr"; then
        printf '%s\n' "$current" >"$SEEN_DIR/checks-$pr"
        echo "CIFAIL pr=$pr head=$head $(printf '%s\n' "$current" | awk -F'\t' '$2=="fail"{print $1}' | tr '\n' ' ')"
        exit 0
      fi
    else
      printf '%s\n' "$current" >"$SEEN_DIR/checks-$pr"
    fi

    current="$(list_threads "$pr")"
    ids="$(printf '%s\n' "$current" | cut -f1 | sed '/^$/d' | sort)"
    new_ids="$(comm -13 "$SEEN_DIR/$pr" <(printf '%s\n' "$ids"))"
    if [ -n "$new_ids" ]; then
      echo "FOUND pr=$pr $(printf '%s\n' "$new_ids" | wc -l | tr -d ' ') new CodeRabbit thread(s)"
      while IFS= read -r id; do
        [ -z "$id" ] && continue
        printf '%s\n' "$current" | awk -F'\t' -v want="$id" '$1 == want { print "=== " $2; print $3; print "" }'
        echo "$id" >>"$SEEN_DIR/$pr"
      done <<<"$new_ids"
      sort -o "$SEEN_DIR/$pr" "$SEEN_DIR/$pr"
      exit 0
    fi
  done

  if gh pr view "${PRS[0]}" --repo "$REPO" --json comments \
    --jq '.comments[] | select(.author.login == "coderabbitai") | .body' 2>/dev/null \
    | rg -qi 'rate limit|review limit|limit reached|next review in'; then
    if [ "$limited" -eq 0 ]; then
      echo "RATE_LIMIT CodeRabbit reports a review limit on a watched pull request"
      limited=1
    fi
  else
    limited=0
  fi

  sleep "$INTERVAL"
done

if [ "$limited" -eq 1 ]; then
  echo "RATE_LIMIT watched pull requests stayed rate-limited for ${DEADLINE_SECONDS}s"
  exit 0
fi

echo "TIMEOUT no new state on ${#PRS[@]} watched pull request(s) after ${DEADLINE_SECONDS}s"
exit 0
