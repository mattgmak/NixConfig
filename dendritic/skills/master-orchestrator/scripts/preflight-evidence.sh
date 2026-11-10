#!/usr/bin/env bash
# Preflight for simulator evidence (skill: master-orchestrator, reference/evidence.md).
#
# Prints the facts a lane must paste before the first capture. Host side only:
# worktree, head, branch, and which Metro serves this worktree. The four device
# checks print as a checklist, because the manzanas tools hold them.
#
# Usage: preflight-evidence.sh
# Exit 0 when a Metro serves this worktree, 1 when none does.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "FAIL: run this in a git worktree"
  exit 1
}

HEAD=$(git -C "$ROOT" rev-parse --short HEAD)
BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
DIRTY=$(git -C "$ROOT" status --porcelain | wc -l | tr -d ' ')

SELF=""
if command -v tailscale >/dev/null 2>&1; then
  SELF=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // ""' | sed 's/\.$//')
fi
[ -z "$SELF" ] && SELF=$(hostname -s | tr '[:upper:]' '[:lower:]')

echo "worktree $ROOT"
echo "head     $HEAD"
echo "branch   $BRANCH"
echo "dirty    $DIRTY"

found=0
while read -r port pid; do
  [ -n "${pid:-}" ] || continue
  comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "")
  case "$comm" in
    node* | expo* | bun*) ;;
    *) continue ;;
  esac
  cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || continue
  [ "$cwd" = "/" ] && continue
  # A Metro child sits inside the app dir, so crop at node_modules.
  case "$cwd" in
    */node_modules*) cwd=$(printf '%s' "$cwd" | sed 's#/node_modules/.*##') ;;
  esac
  if [ "$cwd" = "$ROOT" ]; then
    echo "metro    http://$SELF:$port"
    found=1
  else
    echo "FOREIGN  http://$SELF:$port serves $cwd"
  fi
done < <(ss -ltnpH 2>/dev/null |
  sed -nE 's/.*:([0-9]{2,5})[[:space:]].*pid=([0-9]+).*/\1 \2/p' |
  sort -u)

if [ "$found" -eq 0 ]; then
  echo "metro    NONE for this worktree"
fi

cat <<'CHECK'

Paste these four lines before the first capture:
[ ] lease  id, TTL left, device, and the client installed from this head
[ ] bundle one visible word drawn from this head, then reverted
[ ] tools  dev Tools button off, or the gear bubble clear of the header
[ ] tap    the a11y tree reports points, so a pixel tap is 3x

A FOREIGN line is the trap: the device then runs another checkout, and every
capture proves nothing.
CHECK

[ "$found" -eq 1 ] || exit 1
