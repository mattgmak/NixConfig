#!/usr/bin/env bash
# Publish evidence stills into a pull request body (reference/evidence.md).
#
# Uploads each image with `gh pr edit --attach`, so GitHub mints a
# user-attachments asset and appends the inline image to the body. Nothing is
# committed, nothing goes to a release, and the repository stays clean.
#
# Usage: publish-evidence.sh <pr-number> <folder>
# Example: publish-evidence.sh 214 /tmp/agent-tmp/tcm/evidence/1515

set -uo pipefail

PR="${1:?publish-evidence.sh needs a pull request number}"
DIR="${2:?publish-evidence.sh needs a folder}"

[ -d "$DIR" ] || {
  echo "FAIL: no folder $DIR"
  exit 1
}

command -v gh >/dev/null || {
  echo "FAIL: no gh"
  exit 1
}

GH_MAJOR=$(gh --version | head -1 | awk '{print $3}' | cut -d. -f1)
GH_MINOR=$(gh --version | head -1 | awk '{print $3}' | cut -d. -f2)
if [ "${GH_MAJOR:-0}" -lt 2 ] || { [ "$GH_MAJOR" -eq 2 ] && [ "${GH_MINOR:-0}" -lt 99 ]; }; then
  echo "FAIL: gh 2.99.0 or later is required for --attach"
  exit 1
fi

count=0
for f in "$DIR"/*.png "$DIR"/*.gif "$DIR"/*.jpg; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  gh pr edit "$PR" --attach "$f" >/dev/null || {
    echo "FAIL: attach $name"
    exit 1
  }
  echo "attached $name"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "FAIL: no image in $DIR"
  exit 1
fi

echo "--- body asset urls ---"
gh pr view "$PR" --json body -q .body | rg -o 'https://github\.com/user-attachments/assets/[0-9a-f-]+' || true

# The lease rule: release only after every still shows in the body.
echo "Attached $count images to #$PR. Release the lease only after the body renders them."
echo "Name the screen and the proof beside each image, and keep the head sha in the block."
