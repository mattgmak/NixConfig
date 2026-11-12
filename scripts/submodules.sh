#!/bin/sh
# Manual entry point for both submodule hooks: clean, then refresh.
# post-merge runs the same pair with refresh detached; this waits for both.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$root/githooks/submodule-clean.sh"
"$root/githooks/submodule-refresh.sh"
