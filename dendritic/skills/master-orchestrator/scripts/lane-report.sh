#!/usr/bin/env bash
# Open a lane report file with the frozen fields (reference/agent-loop.md).
#
# A lane writes detail here and replies with three lines. The master reads the
# file only when a fact is missing, so the chat stays small.
#
# Usage: lane-report.sh <lane> <phase> "<one line summary>"
# Phases: plan, code, gate, evidence, pr

set -uo pipefail

LANE="${1:?lane-report.sh <lane> <phase> \"<summary>\"}"
PHASE="${2:?phase: plan, code, gate, evidence or pr}"
SUMMARY="${3:-}"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$ROOT")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo none)
DIR="/tmp/agent-tmp/$PROJECT/reports"
FILE="$DIR/$LANE-$PHASE.md"

mkdir -p "$DIR"

cat >"$FILE" <<REPORT
# $LANE — $PHASE

head: $HEAD
summary: $SUMMARY

## Head
## Changed files
## Gate exits
## Evidence artifacts
## Blockers
## Next step
REPORT

echo "report $FILE"
echo "--- reply with three lines only ---"
echo "1. $SUMMARY"
echo "2. head $HEAD, gates: <name exit> ..."
echo "3. next: <one step>, or done"
