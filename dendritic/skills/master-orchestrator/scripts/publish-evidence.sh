#!/usr/bin/env bash
# Publish evidence artifacts and print the body rows (reference/evidence.md).
#
# Uploads every image in a folder to the `evidence` release, then prints the
# table rows and the inline images for the pull request body. Fill SCREEN and
# PROOF in the body; this script fills the name, the head and the url.
#
# Usage: publish-evidence.sh <folder> [tag]
# Default tag: evidence

set -uo pipefail

DIR="${1:?publish-evidence.sh needs a folder}"
TAG="${2:-evidence}"

[ -d "$DIR" ] || {
  echo "FAIL: no folder $DIR"
  exit 1
}

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner) || {
  echo "FAIL: no GitHub repo"
  exit 1
}
HEAD=$(git rev-parse --short HEAD)
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$ROOT")

count=0
rows="/tmp/agent-tmp/$PROJECT/evidence-rows.md"
mkdir -p "$(dirname "$rows")"
: >"$rows"

for f in "$DIR"/*.png "$DIR"/*.gif "$DIR"/*.jpg; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  gh release upload "$TAG" "$f" --clobber >/dev/null || {
    echo "FAIL: upload $name"
    exit 1
  }
  printf '| `%s` | SCREEN | `%s` | PROOF |\n' "$name" "$HEAD" >>"$rows"
  printf '![%s](https://github.com/%s/releases/download/%s/%s)\n\n' \
    "$name" "$REPO" "$TAG" "$name" >>"$rows"
  count=$((count + 1))
  echo "uploaded $name"
done

if [ "$count" -eq 0 ]; then
  echo "FAIL: no image in $DIR"
  exit 1
fi

echo "rows in $rows"
echo "--- body block ---"
echo "## Evidence"
echo
cat "$rows"

# The lease rule: release only after this script prints its count.
echo "Release the lease only after the body holds these $count images."
