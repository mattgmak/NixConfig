---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> [implementation notes] e.g. mattmak/prd-239-dashboard-banner-add-url configurable openLink on press"
---

# Work on Linear Ticket

Worktree + Pi session for Linear branch. Parent pi quits gracefully after handoff (step 6) — deferred `/quit`, never inline `kill`.

## Invocation

Branch in Linear git-branch format required. Text after branch → impl direction for Pi.

```
mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

Slug after `/` = issue id (`prd-239` → `PRD-239`).

## Workflow

### 0. Preflight (shell allowlist)

All shell cmds via `mcp_pi_shell` / `mcp_pi_ctx_shell` — native Shell maybe unavailable.

`wt`/`sesh`/`tmux`/`jq` pre-allowed in `home-modules/pi-coding-agent/lean-ctx/config.toml`. Widen: `lean-ctx allow <binary>` (user approves).

`[BLOCKED — DO NOT RETRY]` → `lean-ctx allow <binary>`; declined → user adds to `lean-ctx/config.toml` (+ `home-manager switch` / Pi restart). No blind retry.

**`$(...)` gotcha:** allowlist tokenizes *inside* `$(...)`; every token (flags `-C`, words `list`) must be allowlisted. `$(sesh list -j | …)`, `$(git -C …)`, `$(printf …)` rejected — even when `sesh`/`git`/`printf` allowed. `lean-ctx allow` can't fix (flagged tokens ≠ binaries). Fix: multi-step logic → script file → `bash <script>`; allowlist gates only top-level `bash` (step 5).

### 1. Parse branch

First token = branch; rest = impl notes.

Linear id from slug (after `/`):

- Match `([a-z]+)-(\d+)`
- Uppercase team prefix → `PRD-239`

No match → stop, ask valid branch/id.

### 2. Fetch issue

Parallel: `git rev-parse --show-toplevel` + Linear MCP `get_issue` (e.g. `PRD-239`).

Read title, desc, status, labels, linked PRs → work context.

### 3. Create worktree

From cwd (inside target repo):

```bash
wt switch -b @ -c <branch_name>
```

Branch exists → fallback:

```bash
wt switch <branch_name>
```

Capture stdout/stderr. Parse worktree path from text (`--format json` unsupported):

- Primary: `worktree @ <path>` (absolute)
- Fallback: `@ <path>` end of success line

Example:

```
✓ Created branch mattmak/prd-239-... from staging and worktree @ /Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url
```

Confirm `test -d <path>` before continuing.

### 4. Build Pi prompt

Single-quoted prompt: issue id+title, desc/acceptance criteria, impl notes, explore+implement+test instruction, linked PR context. Concise — Pi fetches more itself.

Example shape:

```
Work on Linear issue PRD-239: Dashboard -> Banner -> Add URL.

Can add URL for the banner?

Implement a configurable on-press open link URL for the dashboard banner. When users tap/press the banner, it should open the configured URL.

Explore the codebase, implement a fix, and verify with tests. Start by understanding how the dashboard banner is configured and rendered.
```

### 5. Launch session (detached)

**No `sesh connect`** — `switch-client`s when `$TMUX` set → yanks you out of current session.

Background tmux instead (sesh internals: `new-session -d`, `send-keys`).

**Why script file:** allowlist rejects `$(...)` cmds (step 0); logic `$()`-heavy. Allowlist gates only top-level cmd → logic into temp script, invoke once via `bash`.

Write the script to a temp path you choose (e.g. under `$TMPDIR` or another scratch dir); do not commit it:

```bash
#!/usr/bin/env bash
set -euo pipefail
worktree_path="$1"
prompt="$2"

# 1) Reuse existing tmux session rooted at this worktree
session=$(sesh list -j | jq -r --arg p "$worktree_path" '.[] | select(.Path == $p and .Src == "tmux") | .Name' | head -1)

# 2) Else derive sesh-style git name (gitName + convertToValidName)
if [ -z "$session" ]; then
  # main_root = git MAIN worktree — can differ from repo dir (staging often linked worktree)
  main_root=$(git -C "$worktree_path" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  rel="${worktree_path#$main_root}"
  repo_parts=$(printf '%s' "$main_root" | tr '/' '\n' | tail -2 | paste -sd/ -)
  session=$(printf '%s%s' "$repo_parts" "$rel" | tr '.:' '__' | tr ' ' '_')
fi

# pi runs under node; idle pane shows shell → pane_current_command = pi-alive check
pi_running() {
  tmux list-panes -t "$session" -F '#{pane_current_command}' 2>/dev/null | grep -q '^node$'
}

# 3) Create session if missing
if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux new-session -d -s "$session" -c "$worktree_path"
  echo "created session: $session"
  sleep 1
fi

# 4) Launch pi unless already running (dead session w/ no pi → re-send prompt)
if pi_running; then
  echo "reusing existing pi session: $session"
else
  tmux send-keys -t "$session" "pi '$prompt'" Enter
  echo "sent pi prompt"
fi

# 5) Verify pi up (poll — no blind sleep)
for i in $(seq 1 15); do
  if pi_running; then
    echo "pi confirmed running"
    echo "SESSION=$session"
    break
  fi
  sleep 1
done

if ! pi_running; then
  echo "WARN: pi not detected in $session — attach + check manually" >&2
  echo "SESSION=$session"
  echo "NOTE: handoff failed — parent agent left alive" >&2
  exit 1
fi

# 6) Handoff report — printed AND appended to file. Parent quits shortly after
#    script returns (step 7), so stdout may never render; the file is durable.
branch="${3:-unknown}"
issue="${4:-unknown}"
url="${5:-unknown}"
report_file="${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt"
mkdir -p "$(dirname "$report_file")"
{
  echo ""
  echo "=== Linear ticket handoff $(date '+%Y-%m-%d %H:%M:%S') ==="
  echo "Issue:      $issue"
  echo "URL:        $url"
  echo "Branch:     $branch"
  echo "Worktree:   $worktree_path"
  echo "Tmux:       $session"
  echo "Attach:     sesh connect $worktree_path   |   tmux attach -t $session"
  echo "Report:     $report_file"
} | tee -a "$report_file"

# 7) Graceful parent exit — NEVER kill parent inline while this script still runs
#    as a pi tool call. Inline kill interrupts agent_settled → stale ctx errors in
#    pi-agent-sesh, pi-lens, pi-observational-memory.
#    Instead: script returns → tool completes → agent_settled → deferred /quit.
#    Worker pi is in a DIFFERENT tmux session — never touched.

resolve_parent_tmux_pane() {
  if [ -n "${TMUX_PANE:-}" ]; then
    printf '%s' "$TMUX_PANE"
    return 0
  fi
  p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
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

quit_delay="${PI_HANDOFF_QUIT_DELAY:-2}"
parent_pane=$(resolve_parent_tmux_pane || true)

if [ -n "$parent_pane" ]; then
  (
    sleep "$quit_delay"
    tmux send-keys -t "$parent_pane" '/quit' Enter 2>/dev/null || true
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo "handoff complete — parent /quit in ${quit_delay}s"
  exit 0
fi

# Fallback (no tmux pane): deferred SIGTERM, still not inline
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
  exit 0
fi

echo "WARN: parent tmux pane / agent pid not found — leaving parent alive" >&2
echo "handoff succeeded; session: $session; report: $report_file" >&2
exit 0
```

Run (extra args feed the handoff report — branch, issue id, Linear URL):

```bash
bash "<path-to-script>" "$worktree_path" 'initial_prompt' "<branch>" "<issue_id>" "<issue_url>"
```

Escape single quotes in prompt (`'\''`). `test -d` worktree first. Session name on `SESSION=` line (also in created/reuse msg).

`tmux new-session -d` returns immediately; current client untouched. Non-zero exit/stderr = failure — incl. pi not detected (script polls up to 15s, then WARNs + exits 1, parent stays alive). Success → script schedules deferred parent `/quit` (default 2s, `PI_HANDOFF_QUIT_DELAY`); durable report → `${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt`.

### 6. Handoff — report then graceful parent exit

Success → script (step 5) prints handoff report + appends to `${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt`, then **schedules deferred `/quit`** on parent pi (default 2s delay via detached subshell — lets `agent_settled` finish on live ctx). Parent session ends cleanly → shell prompt. Re-attach anytime: `sesh connect <worktree_path>` / `tmux attach -t <session>`.

| Field | Value |
|-------|-------|
| Issue | arg 4 (id + title) |
| URL | arg 5 (Linear link) |
| Worktree | absolute path |
| Branch | arg 3 / branch name |
| Tmux session | session name (attach: `sesh connect <worktree_path>` / `tmux attach -t <session>`) |
| Report file | `${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt` |
| Quit delay | `PI_HANDOFF_QUIT_DELAY` (default `2` seconds) |

Parent exit only after confirmed handoff (`pi confirmed running`). WARN/non-zero (pi never started) → parent stays alive, prints failure + manual attach cmds. Never quit parent when worker failed (nothing to hand off to). **Never inline-kill parent** — causes stale-ctx extension errors during `agent_settled`.

## Error handling

| Failure | Action |
|---------|--------|
| Blocked by allowlist | `$(...)` cmd → bash script, run `bash <script>` (steps 0/5) — flagged token usually not binary, can't allowlist. Missing binary → `lean-ctx allow <binary>` (user approves); declined → user adds to `home-modules/pi-coding-agent/lean-ctx/config.toml` |
| Not in git repo | Tell user `cd` into repo |
| Linear issue not found | Show extracted id; ask confirm |
| `wt switch` fails | Show stderr; suggest `wt list` |
| Can't parse worktree path | Parse `worktree @ <path>` from stdout; or ask user path |
| `send-keys` → `can't find pane` | `=` prefix breaks send-keys target (names w/ `/`). Drop `=`, use plain `"$session"`. `has-session` tolerates `=`, `send-keys` doesn't |
| Session exists but pi never starts | `pane_current_command` check: pi runs under `node`, idle pane shows shell → script re-sends prompt if pane idle (no silent dead session) |
| `tmux`/`jq`/launch fails | Show stderr; give worktree path + session name + manual attach cmd |
| Parent quit fails (pane/pid not found) | Handoff already done; script WARNs + parent lives. Session/worktree in report file (also `sesh list`). Manual: `/quit` |

## Example

```
/work-on-linear-ticket mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

1. `wt`/`sesh`/`tmux`/`jq` (managed lean-ctx allowlist)
2. Extract `PRD-239`; notes → "do a configurable on press openLink url"
3. Fetch Linear issue (parallel `git rev-parse`)
4. `wt switch -b @ -c mattmak/prd-239-dashboard-banner-add-url`
5. Parse worktree path (e.g. `/Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url`)
6. Detached tmux + `pi 'Work on PRD-239: ...'` (no switch)
7. Script reports + schedules parent `/quit` (step 6); session/worktree in report file
