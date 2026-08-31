#!/usr/bin/env bash
# Deferred graceful exit for parent pi after worker handoff.
# Source from launch-worker.sh — do not run directly.
# NEVER inline-kill parent during tool call (stale ctx in pi-agent-sesh, pi-lens, OOM).

resolve_parent_tmux_pane() {
  if [ -n "${TMUX_PANE:-}" ]; then
    printf '%s' "$TMUX_PANE"
    return 0
  fi
  local p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    local comm pane
    comm=$(ps -o comm= -p "$p" 2>/dev/null | tr -d ' ')
    case "$comm" in
      pi*|node*)
        pane=$(ps eww -p "$p" 2>/dev/null | tr ' ' '\n' | sed -n 's/^TMUX_PANE=//p' | head -1)
        if [ -n "$pane" ]; then
          printf '%s' "$pane"
          return 0
        fi
        ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  return 1
}

schedule_parent_quit() {
  local quit_delay="${PI_HANDOFF_QUIT_DELAY:-2}"
  local parent_pane agent_pid p comm

  parent_pane=$(resolve_parent_tmux_pane || true)
  if [ -n "$parent_pane" ]; then
    (
      sleep "$quit_delay"
      tmux send-keys -t "$parent_pane" '/quit' Enter 2>/dev/null || true
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo "handoff complete — parent /quit in ${quit_delay}s"
    return 0
  fi

  p=$$
  agent_pid=""
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    comm=$(ps -o comm= -p "$p" 2>/dev/null | tr -d ' ')
    case "$comm" in
      pi*|node*) agent_pid="$p" ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done

  if [ -n "$agent_pid" ]; then
    (
      sleep "$quit_delay"
      kill "$agent_pid" 2>/dev/null || true
      sleep 2
      kill -0 "$agent_pid" 2>/dev/null && kill -9 "$agent_pid" 2>/dev/null || true
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo "handoff complete — parent SIGTERM in ${quit_delay}s (no tmux pane)"
    return 0
  fi

  echo "WARN: parent tmux pane / agent pid not found — leaving parent alive" >&2
  return 1
}
