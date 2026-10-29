#!/bin/sh
# Fail when the tool-allowlist reports a tool that no review entry covers.
# Sandbox-safe: sh and coreutils only. No node. No rg.

set -u

if [ -n "${PI_BIN:-}" ]; then
  :
elif command -v pi >/dev/null 2>&1; then
  PI_BIN=pi
elif [ -n "${PI_COMPILED:-}" ]; then
  PI_BIN=$PI_COMPILED/libexec/pi/pi
else
  printf 'tool-audit: no pi binary: set PI_BIN or PI_COMPILED, or put pi on PATH\n' >&2
  exit 2
fi

if [ -z "${EXT_DIR:-}" ]; then
  EXT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)/extensions
fi

n=0
set --
# A compiled host loads its own extension set, so pass no -e flag.
if [ "${PI_AUDIT_COMPILED:-0}" != 1 ]; then
  for d in "$EXT_DIR"/*/; do
    [ -d "$d" ] || continue
    case "$d" in */vendor/) continue ;; esac
    [ -f "$d/package.json" ] || continue
    set -- "$@" -e "$d/index.ts"
    n=$((n + 1))
  done
fi

out=$(printf '' | "$PI_BIN" -ne "$@" --mode rpc 2>&1)

bad=$(printf '%s\n' "$out" | grep '^\[tool-allowlist\] unknown:')
if [ -n "$bad" ]; then
  printf '%s\n' "$bad"
  exit 1
fi

printf 'tool-audit: ok (%s loaders)\n' "$n"
exit 0
