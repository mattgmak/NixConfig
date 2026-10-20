---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> [implementation notes] e.g. mattmak/prd-239-dashboard-banner-add-url configurable openLink on press"
---

# Work on Linear Ticket

Worktree + detached pi peer for a Linear branch. Parent stays alive — never inline kill.

## Skill root + scripts

Skill root = parent dir of this `SKILL.md`. Scripts committed under `scripts/` — **do not** write temp copies. Worktree parser + peer spawn live in **parallel-work** skill.

| Script or tool | Purpose |
|--------|---------|
| `scripts/parse-issue-id.sh` | Branch slug → `PRD-239` |
| `$SPAWN_SKILL_ROOT/scripts/prepare-worktree.sh` | Worktree prep: `wt switch` (+ `--existing`), prints `WORKTREE=<path>` |
| `$SPAWN_SKILL_ROOT/scripts/parse-worktree-path.sh` | `wt switch` output → absolute worktree path |
| `subagent` ext tool | Spawn: `agent: "peer"`, `surface`, `name`, `cwd`, `task` |
| `subagent_message` ext tool | Steer a running peer, resume a finished peer |

Resolve roots at runtime (pick one that exists):

```bash
SKILL_ROOT="${PI_SKILL_ROOT:-$HOME/.pi/agent/skills/work-on-linear-ticket}"
SPAWN_SKILL_ROOT="${PI_SKILL_ROOT:-$HOME/.pi/agent/skills/parallel-work}"
# NixConfig dev:
# SKILL_ROOT="$(git rev-parse --show-toplevel)/dendritic/skills/work-on-linear-ticket"
# SPAWN_SKILL_ROOT="$(git rev-parse --show-toplevel)/dendritic/skills/parallel-work"
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
bash "$SPAWN_SKILL_ROOT/scripts/prepare-worktree.sh" "$PWD" "<branch_name>"
# prints WORKTREE=/abs/path
```

Branch exists → add `--existing`. Manual equivalent: `wt switch -b @ -c <branch_name>`.

`prepare-worktree.sh` parses the path itself and prints `WORKTREE=`. Manual runs:

```bash
bash "$SPAWN_SKILL_ROOT/scripts/parse-worktree-path.sh" <<<"$wt_output"
# or: wt switch ... 2>&1 | bash "$SPAWN_SKILL_ROOT/scripts/parse-worktree-path.sh"
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

### 5. Spawn peer (detached session)

**No `sesh connect`** — switch-clients when `$TMUX` set → yanks current session.

Delegate the launch to the `subagent` ext tool. Peer = full pi, all extensions.

```text
subagent {
  agent:   "peer",
  name:    "<PRD-239>",
  cwd:     "<worktree_path>",
  surface: "NEW <PRD-239>",
  task:    "<initial_prompt + Linear url>"
}
```

`test -d` worktree first. Never call tmux or pi directly — the extension owns target creation. Spawn returns at once; no wait, no poll, no `sesh connect`. Result arrives later as a steer message. Parent stays alive.

### 6. Handoff

Spawn acknowledgement → peer runs in its own session. Re-attach: `sesh connect <worktree_path>` / `tmux attach -t <peer-session>`.

| Field | Source |
|-------|--------|
| Issue | `parse-issue-id.sh` |
| URL | Linear `get_issue` |
| Worktree | `WORKTREE=` line from `prepare-worktree.sh` |
| Branch | git branch |
| Peer name / session | `name` + `surface` in the spawn call |
| Steer | `subagent_message` with the peer name |

Parent stays alive. **Never inline-kill parent** — stale ctx during `agent_settled`. Read-only probe: `bash "$SPAWN_SKILL_ROOT/scripts/verify-peer.sh" <PRD-239>`.

## Error handling

| Failure | Action |
|---------|--------|
| Blocked by allowlist | Use `bash "$SKILL_ROOT/scripts/..."` not inline `$(...)`. Missing binary → `lean-ctx allow` or `config.toml` |
| Not in git repo | User `cd` into repo — peer spawn also needs `$TMUX` set (tmux gate) |
| Linear issue not found | Show extracted id; ask confirm |
| `wt switch` fails | Show stderr; `wt list` |
| Can't parse worktree path | Re-run `parse-worktree-path.sh`; or ask user path |
| Session name taken | User edits the peer name, or pick a fresh `NEW <name>` surface |
| Spawn error result | Read the tool result text; fix the field it names; respawn |
| Target rejects as in-session | Peer needs `new-window`, a session name, or `NEW <name>` — never the caller's pane |
| pi not up in peer | `verify-peer.sh <name>` — pane tail + `CWD`, exit 3. Raise `--wait` or attach |
| `tmux`/`jq` fails | stderr + worktree + manual attach cmd |

## Example

```
/work-on-linear-ticket mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

1. `parse-issue-id.sh` → `PRD-239`
2. Fetch Linear issue (parallel `git rev-parse`)
3. `wt switch -b @ -c mattmak/prd-239-dashboard-banner-add-url`
4. `parse-worktree-path.sh` → e.g. `/Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url`
5. `prepare-worktree.sh <repo> <branch>` → `WORKTREE=…`
6. `subagent { agent: "peer", name: "PRD-239", surface: "NEW PRD-239", cwd: <worktree>, task: … }`
