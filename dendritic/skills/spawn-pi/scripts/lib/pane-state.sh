#!/usr/bin/env bash
# Shared tmux pane introspection for spawn-pi launcher + verifier.
# Source only — no side effects, no local `set` changes, no tmux mutation.

# pi's foreground process name differs by runtime: node (node pi), bun
# (bun-compiled pi), pi (self-contained native binary)
PI_PROC_RE='^(node|bun|pi)$'

pi_at() { # pi_at <target> — pi running in target session/window?
  local target="${1:?target required}"
  tmux list-panes -t "$target" -F '#{pane_current_command}' 2>/dev/null | grep -qE "$PI_PROC_RE"
}

window_exists() { # window_exists <session:window>
  tmux list-windows -t "${1%%:*}" -F '#{window_name}' 2>/dev/null | grep -Fxq -- "${1##*:}"
}

pane_capture() { # pane_capture <target> [history_lines]
  local target="${1:?target required}" hist="${2:-400}"
  tmux capture-pane -p -t "$target" -S "-$hist" 2>/dev/null
}

squeeze_ws() { printf '%s' "${1:-}" | tr -d '[:space:]'; }

pane_last_line() { # pane_last_line <target> [history_lines] — bottom-most non-empty
  pane_capture "${1:?target required}" "${2:-400}" \
    | sed -e 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$' | tail -1
}

# Typed-but-unsubmitted probe. Markers (needles) are matched whitespace-insensitively
# against the bottom-most non-empty line — a submitted prompt lives further up the
# scrollback, so it only matches while sitting unsent in the input box.
pane_line_matches() { # pane_line_matches <target> <needle>...
  local target="${1:?target required}"
  shift
  local last sq needle
  last=$(pane_last_line "$target" 400)
  [ -n "$last" ] || return 1
  sq=$(squeeze_ws "$last")
  for needle in "$@"; do
    needle=$(squeeze_ws "$needle")
    [ "${#needle}" -ge 8 ] || continue
    case "$sq" in *"$needle"*) return 0 ;; esac
  done
  return 1
}

pane_box_line() { # pane_box_line <target> — bottom line is a pi input box ('>' gutter) with text
  local last
  last=$(pane_last_line "${1:?target required}" 400)
  [ -n "$last" ] || return 1
  printf '%s' "$last" | grep -qE '^[[:space:]]*(>|[❯│])[[:space:]]*[^[:space:]>│❯]'
}

pane_box_has_text() { pane_box_line "${1:?target required}"; }

pane_box_line_matches() { # pane_box_line_matches <target> <needle>... — box line holds needle
  local target="${1:?target required}"
  shift
  pane_box_line "$target" && pane_line_matches "$target" "$@"
}

pane_has_submitted_message() { # pane_has_submitted_message <target> — >-gutter message above box
  local body
  body=$(pane_capture "${1:?target required}" 400 \
    | sed -e 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$')
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | wc -l)" -gt 1 ] || return 1
  printf '%s\n' "$body" | sed '$d' | grep -qE '^[[:space:]]*>[[:space:]]*[^[:space:]]'
}

model_from_pane() { # model_from_pane <target> [history_lines] — best-effort model id
  pane_capture "${1:?target required}" "${2:-120}" \
    | grep -oE '(claude|gpt|gemini|codex|grok|qwen|kimi|glm|deepseek|sonnet|opus|haiku|o[0-9])[A-Za-z0-9._-]*' \
    | tail -1
}

# Distinctive tail of a text body (whitespace stripped) for typed-prompt probes.
tail_marker() {
  local sq
  sq=$(squeeze_ws "${1:-}")
  [ "${#sq}" -ge 8 ] || return 0
  printf '%s' "$sq" | tail -c 24
}
