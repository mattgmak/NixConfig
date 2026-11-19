#!/usr/bin/env bash
# Read and write the master-orchestrator state flags.
#
#   state-flag.sh                 print every flag
#   state-flag.sh get <name>      print one value
#   state-flag.sh set <name> <v>  write one value
#
# The file holds one NAME=value line per flag. A missing file means `rush`
# and `code-review` read off, and `work-mode` reads standard.
set -uo pipefail

FLAG_FILE="${MASTER_ORCHESTRATOR_FLAG:-/tmp/agent-tmp/tcm/master-orchestrator-state-flag}"
KNOWN="rush code-review work-mode"

usage() {
  echo "usage: state-flag.sh [get <name> | set <name> <value>]" >&2
  exit 2
}

allowed_values() {
  case "$1" in
    work-mode) echo "direct or standard" ;;
    *) echo "on or off" ;;
  esac
}

default_value() {
  case "$1" in
    work-mode) echo standard ;;
    *) echo off ;;
  esac
}

read_flag() {
  local name="$1"
  if [ ! -f "$FLAG_FILE" ]; then
    default_value "$name"
    return
  fi
  local value
  value=$(rg -N "^${name}=" "$FLAG_FILE" 2>/dev/null | tail -1 | cut -d= -f2)
  echo "${value:-$(default_value "$name")}"
}

write_flag() {
  local name="$1" value="$2"
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
  local others
  others=$(rg -N -v "^${name}=" "$FLAG_FILE" 2>/dev/null || true)
  {
    [ -n "$others" ] && echo "$others"
    echo "${name}=${value}"
  } > "${FLAG_FILE}.new"
  mv "${FLAG_FILE}.new" "$FLAG_FILE"
}

case "${1:-}" in
  "")
    for name in $KNOWN; do
      echo "${name}=$(read_flag "$name")"
    done
    ;;
  get)
    [ $# -eq 2 ] || usage
    read_flag "$2"
    ;;
  set)
    [ $# -eq 3 ] || usage
    case "$2:$3" in
      work-mode:direct|work-mode:standard|rush:on|rush:off|code-review:on|code-review:off) ;;
      *) echo "value reads $(allowed_values "$2")" >&2; exit 2 ;;
    esac
    write_flag "$2" "$3"
    read_flag "$2"
    ;;
  *)
    usage
    ;;
esac
