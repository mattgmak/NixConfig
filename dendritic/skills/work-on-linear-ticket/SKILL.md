---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> [implementation notes] e.g. mattmak/prd-239-dashboard-banner-add-url configurable openLink on press"
---

# Work on Linear Ticket

Worktree + detached Pi worker for Linear branch. Parent pi quits after handoff — deferred `/quit`, never inline kill.

## Skill root + scripts

Skill root = parent dir of this `SKILL.md`. Scripts committed under `scripts/` — **do not** write temp copies.

| Script | Purpose |
|--------|---------|
| `scripts/parse-issue-id.sh` | Branch slug → `PRD-239` |
| `scripts/parse-worktree-path.sh` | `wt switch` output → absolute worktree path |
| `scripts/launch-worker.sh` | Detached tmux + pi + handoff report + deferred parent quit |
| `scripts/lib/parent-quit.sh` | Sourced by launcher — not invoked alone |

Resolve skill root at runtime (pick one that exists):

```bash
SKILL_ROOT="${PI_SKILL_ROOT:-$HOME/.pi/agent/skills/work-on-linear-ticket}"
# NixConfig dev: SKILL_ROOT="$(git rev-parse --show-toplevel)/dendritic/skills/work-on-linear-ticket"
```

## Invocation

Branch = Linear git-branch format. Text after branch → impl notes for worker Pi.

```
mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

## Workflow

### 0. Preflight (shell allowlist)

Shell via `mcp_pi_shell` / `mcp_pi_ctx_shell` — native Shell maybe unavailable.

`wt`/`sesh`/`tmux`/`jq`/`bash` pre-allowed in `home-modules/pi-coding-agent/lean-ctx/config.toml`. Widen: `lean-ctx allow <binary>`.

`[BLOCKED — DO NOT RETRY]` → `lean-ctx allow <binary>`; declined → user adds to `lean-ctx/config.toml` (+ `home-manager switch` / Pi restart).

**`$(...)` gotcha:** allowlist tokenizes inside subshells; flags/words must be allowlisted separately. `lean-ctx allow` can't fix non-binary tokens. Fix → call committed `scripts/*.sh` via top-level `bash` (allowlist gates only top-level `bash`).

### 1. Parse branch

First token = branch; rest = impl notes.

```bash
bash "$SKILL_ROOT/scripts/parse-issue-id.sh" "<branch>"
```

Slug after `/` → `([a-z]+)-(\d+)` → uppercase prefix (`prd-239` → `PRD-239`). No match → stop, ask valid branch/id.

### 2. Fetch issue

Parallel: `git rev-parse --show-toplevel` + Linear MCP `get_issue` (e.g. `PRD-239`).

Read title, desc, status, labels, linked PRs → work context.

### 3. Create worktree

From cwd (inside target repo):

```bash
wt switch -b @ -c <branch_name>
```

Branch exists → `wt switch <branch_name>`.

Capture stdout+stderr. Parse path:

```bash
bash "$SKILL_ROOT/scripts/parse-worktree-path.sh" <<<"$wt_output"
# or: wt switch ... 2>&1 | bash "$SKILL_ROOT/scripts/parse-worktree-path.sh"
```

`test -d <path>` before continue.

### 4. Build Pi prompt

Single-quoted prompt: issue id+title, desc/acceptance, impl notes, explore+implement+test, linked PR context. Concise — worker fetches more.

Example shape:

```
Work on Linear issue PRD-239: Dashboard -> Banner -> Add URL.

Can add URL for the banner?

Implement a configurable on-press open link URL for the dashboard banner. When users tap/press the banner, it should open the configured URL.

Explore the codebase, implement a fix, and verify with tests. Start by understanding how the dashboard banner is configured and rendered.
```

### 5. Launch worker (detached)

**No `sesh connect`** — switch-clients when `$TMUX` set → yanks current session.

```bash
bash "$SKILL_ROOT/scripts/launch-worker.sh" \
  "$worktree_path" \
  'initial_prompt' \
  "<branch>" \
  "<issue_id_and_title>" \
  "<linear_url>"
```

Escape single quotes in prompt (`'\''`). `test -d` worktree first.

`tmux new-session -d` returns immediately; current client untouched. Non-zero = failure (pi not detected after 15s poll → parent stays alive). Success → deferred parent `/quit` (default 2s, `PI_HANDOFF_QUIT_DELAY`). Report → `${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt`.

### 6. Handoff

Success → launcher prints report + appends file, schedules deferred `/quit` on parent (lets `agent_settled` finish). Re-attach: `sesh connect <worktree_path>` / `tmux attach -t <session>`.

| Field | Source |
|-------|--------|
| Issue | launch-worker arg 4 |
| URL | launch-worker arg 5 |
| Worktree | arg 1 |
| Branch | arg 3 |
| Tmux session | `SESSION=` line in output |
| Report file | `${TMPDIR:-/tmp}/agent-tmp/linear-ticket-report.txt` |
| Quit delay | `PI_HANDOFF_QUIT_DELAY` (default `2`) |

Parent exit only after `pi confirmed running`. WARN/exit 1 → parent stays alive. **Never inline-kill parent** — stale ctx during `agent_settled`.

## Error handling

| Failure | Action |
|---------|--------|
| Blocked by allowlist | Use `bash "$SKILL_ROOT/scripts/..."` not inline `$(...)`. Missing binary → `lean-ctx allow` or `config.toml` |
| Not in git repo | User `cd` into repo |
| Linear issue not found | Show extracted id; ask confirm |
| `wt switch` fails | Show stderr; `wt list` |
| Can't parse worktree path | Re-run `parse-worktree-path.sh`; or ask user path |
| `send-keys` → `can't find pane` | `=` prefix breaks target (names w/ `/`). Plain `"$session"` — `has-session` tolerates `=`, `send-keys` doesn't |
| Session exists, pi never starts | `pane_current_command` = `node` when pi alive; idle shell → launcher re-sends prompt |
| `tmux`/`jq`/launch fails | stderr + worktree + session + manual attach cmd |
| Parent quit fails | Handoff done; WARN + parent lives. Report file + `sesh list`. Manual `/quit` |

## Example

```
/work-on-linear-ticket mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

1. `parse-issue-id.sh` → `PRD-239`
2. Fetch Linear issue (parallel `git rev-parse`)
3. `wt switch -b @ -c mattmak/prd-239-dashboard-banner-add-url`
4. `parse-worktree-path.sh` → e.g. `/Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url`
5. `launch-worker.sh` with prompt + metadata
6. Parent `/quit` deferred; report in tmp file
