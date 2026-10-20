#!/usr/bin/env bash
# tmux pi worker launcher — detached session (default) or new window in the
# caller's current session (--in-window) + optional graceful parent handoff.
#
# Usage:
#   PI_HANDOFF_QUIT=1 launch-worker.sh [flags] <worktree_path> [prompt] [branch] [label] [url] [session_name]
#
# Flags (must precede positionals):
#   --prompt-file <path>   prompt read from file — preferred, quoting-proof; pass '' as arg 2
#   --orchestrator         prepend orchestrator-mode snippet body (frontmatter stripped here)
#   --snippet <path>       snippet override for --orchestrator
#   --in-window            new window in caller's tmux session ($TMUX); detached default
#
# Args 3–5 feed the handoff report (arg 4 also seeds name auto-derive). Prompt: short
# single-line without quotes goes inline; anything longer/quoted/multi-line goes through
# a prompt file — no caller-side escaping. Arg 6 = name: tmux session/window name AND
# pi session display name (pi -n, searchable via /resume); omitted → auto-derived.
# (exactly one ticket id in prompt+label, else sesh-style path name, else -2/+ bump).
# Stdout keys: SESSION=<name>; WINDOW=<session>:<window> in --in-window mode;
#              PROMPT=<submitted|unsubmitted|unknown|n/a>.
# Deferred parent /quit fires only when PI_HANDOFF_QUIT=1.
# Report file: ${PI_REPORT_FILE:-${TMPDIR:-/tmp}/agent-tmp/agent-handoff-report.txt}
set -euo pipefail

usage_error() {
  echo "ERROR: $*" >&2
  exit 2
}

prompt_file=''
orchestrator=0
snippet_override=''
mode=detached

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt-file)
      [ $# -ge 2 ] || usage_error "--prompt-file needs a path"
      prompt_file=$2
      shift 2
      ;;
    --prompt-file=*) prompt_file=${1#*=}; shift ;;
    --snippet)
      [ $# -ge 2 ] || usage_error "--snippet needs a path"
      snippet_override=$2
      shift 2
      ;;
    --snippet=*) snippet_override=${1#*=}; shift ;;
    --orchestrator) orchestrator=1; shift ;;
    --in-window) mode=window; shift ;;
    --) shift; break ;;
    -*) usage_error "unknown flag: $1" ;;
    *) break ;;
  esac
done

worktree_path="${1:-}"
[ -n "$worktree_path" ] || usage_error "worktree_path required"
prompt="${2:-}"
branch="${3:-unknown}"
issue="${4:-unknown}"
url="${5:-}"
session_override="${6:-}"

if [ -n "$prompt_file" ]; then
  [ -r "$prompt_file" ] || usage_error "--prompt-file not readable: $prompt_file"
  [ -z "$prompt" ] || echo "WARN: inline prompt ignored — --prompt-file wins" >&2
  prompt=$(cat "$prompt_file")
fi
[ -n "$prompt" ] || usage_error "prompt required (inline arg 2 or --prompt-file <path>)"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -n "$snippet_override" ] && [ "$orchestrator" != 1 ]; then
  usage_error "--snippet only applies with --orchestrator"
fi
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/parent-quit.sh
source "$script_dir/lib/parent-quit.sh"
# shellcheck source=lib/pane-state.sh
source "$script_dir/lib/pane-state.sh"

tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}

# --- orchestrator snippet: resolve + strip frontmatter (callers never do this) ---
resolve_snippet() {
  local cand
  if [ -n "$snippet_override" ]; then
    [ -f "$snippet_override" ] || usage_error "--snippet not found: $snippet_override"
    printf '%s\n' "$snippet_override"
    return 0
  fi
  # script_dir = <repo>/dendritic/skills/spawn-pi/scripts → ../../../ = <repo>/dendritic
  # PI_SKILL_ROOT = <repo>/dendritic/skills/spawn-pi   → ../../    = <repo>/dendritic
  for cand in \
    "${PI_ORCHESTRATOR_SNIPPET:-}" \
    "$script_dir/../../../home-modules/pi-coding-agent/extensions/prompt-snippets/snippets/orchestrator-mode.md" \
    "${PI_SKILL_ROOT:+$PI_SKILL_ROOT/../../home-modules/pi-coding-agent/extensions/prompt-snippets/snippets/orchestrator-mode.md}" \
    "$HOME/.pi/agent/extensions/prompt-snippets/snippets/orchestrator-mode.md"; do
    if [ -n "$cand" ] && [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

if [ "$orchestrator" = 1 ]; then
  snippet=$(resolve_snippet) || usage_error \
    "--orchestrator: orchestrator-mode snippet not found (set \$PI_ORCHESTRATOR_SNIPPET or pass --snippet <path>)"
  body=$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$snippet" \
    | awk 'NF {p=1} p')
  [ -n "$body" ] || usage_error "--orchestrator: snippet body empty: $snippet"
  prompt=$(printf '%s\n\n%s' "$body" "$prompt")
fi

# --- name: ticket id from prompt/label wins, else sesh-style git name ---
sanitize_name() { printf '%s' "${1:-}" | tr '.:' '__' | tr ' ' '_'; }

# Linear-style ids ([A-Z]{2,5}-[0-9]{1,5}) as used across these docs (PRD-239).
# Word-delimited, obvious non-ticket tokens (UTF-8, SHA-256) rejected.
ticket_id_from_text() {
  awk '
    {
      line=$0
      while (match(line, /[A-Z][A-Z0-9]*-[0-9][0-9]*/)) {
        id=substr(line, RSTART, RLENGTH)
        pre=(RSTART>1)?substr(line, RSTART-1, 1):""
        line=substr(line, RSTART+RLENGTH)
        post=substr(line, 1, 1)
        dash=index(id,"-")
        p=substr(id,1,dash-1)
        n=substr(id,dash+1)
        if (pre ~ /[A-Za-z0-9]/) continue
        if (post ~ /[0-9]/) continue
        if (length(p) < 2 || length(p) > 5) continue
        if (length(n) < 1 || length(n) > 5) continue
        if (p ~ /^(UTF|SHA|ISO|AES|MD5|TLS|RSA|HTTP|UTC|RGB)$/) continue
        print id
      }
    }
  ' <<<"$1" | sort -u
}

name_busy() { # name_busy <name> — name collision for a derived name
  # window mode: any existing window name blocks — `session:name` must stay unambiguous
  # and a pi-less window may hold unrelated work. detached: only a live pi blocks.
  if [ "$mode" = window ]; then
    window_exists "$session:$1"
  else
    tmux has-session -t "$1" 2>/dev/null && pi_at "$1"
  fi
}

session=''
win_name=''
skip_derive=0

# 0) --in-window: target the caller's own session, detected from $TMUX
if [ "$mode" = window ]; then
  [ -n "${TMUX:-}" ] || usage_error "--in-window requires \$TMUX — caller is not inside tmux"
  caller_session=''
  if [ -n "${TMUX_PANE:-}" ]; then
    caller_session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null || true)
  fi
  [ -n "$caller_session" ] || caller_session=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
  [ -n "$caller_session" ] || usage_error "could not resolve caller tmux session from \$TMUX"
  session=$caller_session
fi

# 1) Explicit name wins — spawn-pi passes arg 6 so workers never collide with the
# parent's pi or other busy sessions
if [ -n "$session_override" ]; then
  # tmux treats '.' & ':' in -t as window/pane separators (can't find pane gotcha)
  name=$(sanitize_name "$session_override")
  skip_derive=1
else
  # Detached only: reuse an existing tmux session rooted at this worktree — but
  # only when no pi is already running in it (running pi = someone else's task;
  # silently swallowing the prompt would strand the work)
  if [ "$mode" = detached ]; then
    reuse_candidate=$(sesh list -j | jq -r --arg p "$worktree_path" '.[] | select(.Path == $p and .Src == "tmux") | .Name' | head -1)
    if [ -n "$reuse_candidate" ]; then
      if pi_at "$reuse_candidate"; then
        session=$(sanitize_name "$reuse_candidate")
        echo "WARN: session $session already runs pi for a different task — prompt NOT sent" >&2
        echo "SESSION=$session"
        exit 0
      fi
      name=$(sanitize_name "$reuse_candidate")
      skip_derive=1
    fi
  fi
fi

# 2) Else derive: ticket id (unique) → sesh-style git name (gitName + convertToValidName)
if [ "$skip_derive" = 0 ]; then
  tickets=$(ticket_id_from_text "$prompt $issue" || true)
  ticket_count=$(printf '%s' "$tickets" | grep -c . || true)
  if [ "$ticket_count" = 1 ]; then
    name=$(sanitize_name "$tickets")
  else
    [ "$ticket_count" -gt 1 ] && echo "WARN: ambiguous ticket ids ($(printf '%s' "$tickets" | paste -sd, -)) — using worktree-derived name" >&2
    # git may legitimately fail (bare dir, not a worktree) — never abort on it
    main_root=$(git -C "$worktree_path" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}' || true)
    if [ -n "$main_root" ]; then
      rel="${worktree_path#"$main_root"}"
      repo_parts=$(printf '%s' "$main_root" | tr '/' '\n' | tail -2 | paste -sd/ -)
      name=$(sanitize_name "$(printf '%s%s' "$repo_parts" "$rel")")
    else
      # no repo root available — last two path components, still sesh-style
      name=$(sanitize_name "$(printf '%s' "$worktree_path" | tr '/' '\n' | tail -2 | paste -sd/ -)")
    fi
  fi
  # Distinctness: if name taken by a busy pi, bump to -2, -3, ...
  while name_busy "$name"; do
    case "$name" in
      *-[0-9]) n=${name##*-}; name="${name%-*}-$((n + 1))" ;;
      *) name="$name-2" ;;
    esac
  done
fi

if [ "$mode" = window ]; then
  win_name=$name
  target="$session:$win_name"
else
  session=$name
  target=$session
fi

print_target() {
  if [ "$mode" = window ]; then
    echo "WINDOW=$target"
    echo "SESSION=$session"
  else
    echo "SESSION=$session"
  fi
}

# 3) Create target if missing — no settle sleep: tmux queues send-keys for pane
# input, poll loop below is the real gate
if [ "$mode" = window ]; then
  if window_exists "$target"; then
    echo "reusing existing window: $target"
  elif tmux new-window -t "$session:" -n "$win_name" -c "$worktree_path"; then
    echo "created window: $target"
  else
    # Race: another process may create the same window name coincidentally.
    # Fall through and verify it exists before giving up.
    echo "WARN: new-window failed for $target — checking for external creation" >&2
  fi
  if ! window_exists "$target"; then
    echo "ERROR: tmux window $target does not exist and could not be created" >&2
    exit 1
  fi
else
  if ! tmux has-session -t "$session" 2>/dev/null; then
    if tmux new-session -d -s "$session" -c "$worktree_path"; then
      echo "created session: $session"
    else
      # Race: another process may create the same session name coincidentally.
      # Fall through and verify it exists before giving up.
      echo "WARN: new-session failed for $session — checking for external creation" >&2
    fi
  fi
  if ! tmux has-session -t "$session" 2>/dev/null; then
    echo "ERROR: tmux session $session does not exist and could not be created" >&2
    exit 1
  fi
fi

# 4) Prompt transport: inline only when short, single-line, quote-free — anything
# else goes through a file (arg quoting + newlines break `tmux send-keys`)
prompt_path=''
sent_cmd=''
needs_file=0
case "$prompt" in
  *"'"*) needs_file=1 ;;
  *$'\n'*) needs_file=1 ;;
esac
[ "${#prompt}" -le 400 ] || needs_file=1
pi_name=$(sanitize_name "$name")

if [ "$needs_file" = 1 ]; then
  prompt_dir="$tmp_root/agent-tmp/spawn-pi"
  mkdir -p "$prompt_dir"
  prompt_path="$prompt_dir/prompt-$$-$(date +%s).txt"
  printf '%s' "$prompt" >"$prompt_path"
  sent_cmd="pi -n \"$pi_name\" \"\$(cat '$prompt_path')\""
else
  sent_cmd="pi -n \"$pi_name\" '$prompt'"
fi

# 5) Launch pi unless already running
sent_prompt=0
if pi_at "$target"; then
  if [ -n "$session_override" ]; then
    echo "WARN: $target already runs pi — prompt NOT sent (use a fresh arg-6 name)" >&2
  fi
  echo "reusing existing pi session: $target"
else
  tmux send-keys -t "$target" "$sent_cmd" Enter
  sent_prompt=1
  echo "sent pi prompt"
fi

# 6) Verify pi up — exponential backoff; pi usually up ~1–2s, ~11s budget
ok=0
for gap in 0.5 0.5 1 2 4 3; do
  if pi_at "$target"; then
    ok=1
    break
  fi
  sleep "$gap"
done
if pi_at "$target"; then ok=1; fi

if [ "$ok" != 1 ]; then
  echo "WARN: pi not detected in $target — attach + check manually" >&2
  print_target
  echo "NOTE: handoff failed — parent agent left alive" >&2
  exit 1
fi
echo "pi confirmed running"

# 7) Prompt-executed check — pi idle at the '>' box with the prompt typed but
# unsubmitted is a known failure. One Enter retry, then report; never loops.
verify_prompt_executed() {
  prompt_needle=$(tail_marker "$prompt")
  cmd_needle=$(tail_marker "$sent_cmd")
  if [ -z "$prompt_needle$cmd_needle" ]; then
    printf 'unknown'
    return 0
  fi
  sleep 1
  if ! prompt_unsubmitted; then
    printf 'submitted'
    return 0
  fi
  echo "WARN: prompt typed but unsubmitted in $target — re-sending Enter once" >&2
  tmux send-keys -t "$target" Enter
  sleep 1
  if prompt_unsubmitted; then
    echo "WARN: prompt still unsubmitted in $target after retry — attach and press Enter" >&2
    printf 'unsubmitted'
  else
    echo "prompt accepted after Enter retry" >&2
    printf 'submitted'
  fi
}

# Unsent prompt = either the launch command still sitting on the pane shell line,
# or the prompt rendered inside pi's input box (known past failure)
prompt_unsubmitted() {
  if [ -n "$prompt_needle" ] && pane_box_line_matches "$target" "$prompt_needle"; then
    return 0
  fi
  if [ -n "$cmd_needle" ] && pane_line_matches "$target" "$cmd_needle"; then
    return 0
  fi
  return 1
}

prompt_status=n/a
if [ "$sent_prompt" = 1 ]; then
  prompt_status=$(verify_prompt_executed)
fi
echo "PROMPT=$prompt_status"
print_target

# 8) Handoff report — stdout + durable file (parent may quit before render)
report_file="${PI_REPORT_FILE:-$tmp_root/agent-tmp/agent-handoff-report.txt}"
mkdir -p "$(dirname "$report_file")"
{
  echo ""
  echo "=== pi handoff $(date '+%Y-%m-%d %H:%M:%S') ==="
  echo "Label:      $issue"
  if [ -n "$url" ]; then echo "URL:        $url"; fi
  echo "Branch:     $branch"
  echo "Worktree:   $worktree_path"
  if [ "$mode" = window ]; then
    echo "Tmux:       $target (window)"
  else
    echo "Tmux:       $session"
  fi
  if [ -n "$prompt_path" ]; then echo "PromptFile: $prompt_path"; fi
  echo "Prompt:     $prompt_status"
  echo "Attach:     sesh connect $worktree_path   |   tmux attach -t $session"
  # plain `[ ... ] && echo` as last command in this group would fail the
  # pipefail'd pipeline under set -e; keep if/then
  if [ "$mode" = window ]; then echo "Focus:      tmux select-window -t $target"; fi
  echo "Report:     $report_file"
} | tee -a "$report_file"

# 9) Deferred parent exit — opt-in via PI_HANDOFF_QUIT=1 (spawn-pi fans out
# multiple workers and keeps the parent; linear-ticket single handoff sets the env)
if [ "${PI_HANDOFF_QUIT:-0}" = "1" ] && schedule_parent_quit; then
  exit 0
fi

echo "handoff succeeded; session: $target; report: $report_file" >&2
exit 0
