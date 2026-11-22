#!/usr/bin/env bash
set -euo pipefail

# Run a Vesktop global shortcut through Vesktop's IPC socket.
# Vesktop 1.7+ exposes the socket; it exists only while Vesktop runs.

action="${1:?usage: vesktop-toggle.sh toggleMute|toggleDeafen}"
printf 'run-shortcut %s' "$action" | socat - "UNIX-CONNECT:${XDG_RUNTIME_DIR:?}/vesktop.sock"
