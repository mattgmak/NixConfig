---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> [implementation notes] e.g. mattmak/prd-239-dashboard-banner-add-url configurable openLink on press"
---

# Work on Linear Ticket

Worktree for Linear branch + Pi session w/ work prompt.

## Invocation

Need branch in Linear git-branch format. Text after branch = impl direction for Pi.

```
mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

Slug after `/` embeds issue id (`prd-239` → `PRD-239`).

## Workflow

### 0. Preflight (shell allowlist)

All shell cmds via `mcp_pi_shell` (or `mcp_pi_ctx_shell`) — native Shell may be unavailable.

`wt`, `sesh`, `tmux`, `jq` pre-allowed in `home-modules/pi-coding-agent/lean-ctx/config.toml`. Widen: `lean-ctx allow <binary>` (user approves).

`[BLOCKED — DO NOT RETRY]` → `lean-ctx allow <binary>`; declined → user adds to `lean-ctx/config.toml` (+ `home-manager switch` / Pi restart). No blind retry.

**`$(...)` gotcha:** allowlist tokenizes *inside* `$(...)`; every token (flags `-C`, words `list`) must be allowlisted. `$(sesh list -j | …)`, `$(git -C …)`, `$(printf …)` rejected though `sesh`/`git`/`printf` allowed. `lean-ctx allow` can't fix (flagged tokens not binaries). Fix: multi-step logic → script file → `bash <script>`; allowlist gates only top-level `bash` (see step 5).

### 1. Parse branch

First token = branch; rest = impl notes.

Extract Linear id from slug (after `/`):

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

Capture stdout/stderr. Parse worktree path from text (no `--format json` — unsupported):

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

**No `sesh connect`** — always `switch-client`s when `$TMUX` set → yanks you out of current session.

Background tmux instead (sesh internals: `new-session -d`, `send-keys`).

**Why script file:** allowlist rejects any `$(...)` cmd (step 0); logic is `$()`-heavy. Allowlist gates only top-level cmd → logic into temp script, invoke once via `bash`.

Script → `$CURRENT_DIRECTORY/claudetmp/` (AGENTS.md) or `$TMPDIR`:

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
    exit 0
  fi
  sleep 1
done

echo "WARN: pi not detected in $session — attach + check manually" >&2
echo "SESSION=$session"
exit 1
```

Run:

```bash
bash "$CURRENT_DIRECTORY/claudetmp/launch-tmux-session.sh" "$worktree_path" 'initial_prompt'
```

Escape single quotes in prompt (`'\''`). `test -d` worktree first. Session name on `SESSION=` line (also in created/reuse msg).

`tmux new-session -d` returns immediately; current client untouched. Non-zero exit/stderr = failure — incl. pi not detected (script polls up to 15s, then WARNs + exits 1).

### 6. Report

| Field | Value |
|-------|-------|
| Issue | `PRD-239` + title + Linear URL |
| Status | from Linear |
| Worktree | absolute path |
| Branch | branch name |
| Tmux session | session name (attach: `sesh connect <worktree_path>` / `tmux attach -t <session>`) |

Confirm Pi launched background — script prints `pi confirmed running`. Failed (WARN/non-zero) → include detached-launch cmds as copy-paste fallback.

## Error handling

| Failure | Action |
|---------|--------|
| Blocked by allowlist | `$(...)` cmd → logic into bash script, run `bash <script>` (steps 0/5) — flagged token usually not binary, can't allowlist. Missing binary → `lean-ctx allow <binary>` (user approves); declined → user adds to `home-modules/pi-coding-agent/lean-ctx/config.toml` |
| Not in git repo | Tell user `cd` into repo |
| Linear issue not found | Show extracted id; ask confirm |
| `wt switch` fails | Show stderr; suggest `wt list` |
| Can't parse worktree path | Parse `worktree @ <path>` from stdout; or ask user path |
| `send-keys` → `can't find pane` | `=` prefix breaks send-keys target (names w/ `/`). Drop `=`, use plain `"$session"`. `has-session` tolerates `=`, `send-keys` doesn't |
| Session exists but pi never starts | `pane_current_command` check: pi runs under `node`, idle pane shows shell → script re-sends prompt if pane idle (no silent dead session) |
| `tmux`/`jq`/launch fails | Show stderr; give worktree path + session name + manual attach cmd |

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
7. Report issue link, worktree, branch, session name
