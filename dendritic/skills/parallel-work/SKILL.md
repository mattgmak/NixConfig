---
name: parallel-work
description: Fan out full-pi `peer` workers to panes, tmux windows, and sessions for work named in the last agent response. Use when user says "parallel work", "fan out pi", "spawn peers", or points at continuation work to run in parallel sessions. Requires tmux.
argument-hint: "[work item hint] — optional; rest extracted from last agent response"
---

# Parallel Work

Spawn `peer` workers for continuation work found in the last agent response. Peer = full pi session: all extensions, all tools, no allowlists. Peers start in a pane, window, or session. Parent stays alive after spawn.

## Peer surfaces

| Placement | Value |
|-----------|-------|
| Pane split beside caller | omit `surface`, or `pane` |
| New window in caller's tmux session | `window` |
| New window inside an existing tmux session | `window:<session>`, or a bare session name |
| Detached new tmux session | `new-session:<name>` |

An agent's `surfaces` frontmatter field limits allowed kinds. Default = `pane` only. Kinds: `pane`, `window`, `session`. A `peer: true` agent allows any surface its `surfaces` lists, pane included. Removed surface values are hard errors — the error names the replacement.

## Ext tools

Use the `interactive-subagents` extension tools. Do not call tmux directly for spawn, steer, or resume.

| Tool | Use |
|------|-----|
| `subagent` | Spawn: `agent: "peer"`, `task`, `name`, `cwd`, `surface` (placement, default `pane`) |
| `subagents_list` | Show peer definitions. Not a status probe — never poll it |
| `subagent_message` | Steer a running peer, or resume a finished peer by name |

Registry names are shared. Any session with the registry map resumes a peer. Resume relaunches into the peer's original session and window.

Steer-back arrives as a steer message. A peer that needs input writes an `.ask` question file. Max wait = 2 hours.

## Skill root + scripts

Skill root = parent dir of this `SKILL.md`. Scripts committed under `scripts/` — **do not** write temp copies.

| Script | Purpose |
|--------|---------|
| `scripts/prepare-worktree.sh` | Worktree prep only: `wt switch` (+ `--existing`), prints `WORKTREE=<path>` |
| `scripts/parse-worktree-path.sh` | `wt switch` output → absolute worktree path |
| `scripts/verify-peer.sh` | Read-only probe, target by peer registry name: pi up, cwd, model, prompt state. Never mutates tmux |

Resolve skill root at runtime (pick one that exists):

```bash
SKILL_ROOT="${PI_SKILL_ROOT:-$HOME/.pi/agent/skills/parallel-work}"
# NixConfig dev: SKILL_ROOT="$(git rev-parse --show-toplevel)/dendritic/skills/parallel-work"
```

## Workflow

### 0. Tmux gate

**Completion criterion:** `$TMUX` non-empty, or stopped.

```bash
[ -n "${TMUX:-}" ] && echo in-tmux
```

Unset → stop. Tell user to run inside tmux. No parsing, no worktrees before this check.

### 1. Extract work items

Optional arg names which items count ('all' when absent). Read the last agent response. Each item → proposal:

- **Task text**: lean summary (worker explores from here — no response chunks embedded verbatim)
- **Context params**: repo / worktree / paths / branch / Linear or GitHub ticket
- **Surface**: `pane`, `window`, `window:<session>`, or `new-session:<name>`

Work tied to an existing checkout reuses it. No branch → propose a name from the ticket.

**Peer heuristic:** touches more than one area, uncertain scope, multi-path fan-out → peer. One confined fix → no peer, do it here.

**Completion criterion:** every continuation item is a proposal, merged into one, or excluded with the user's reason. No silent drops.

### 2. Independence check

- Same repo + overlapping paths/branches/ticket → **merge** into one peer.
- Disjoint repos/worktrees/tickets/paths → **split**.

Unsure → split. The confirm step catches mistakes.

### 3. No concurrency cap

Spawn one peer per confirmed independent item. No limit in the extension, none here. User drops items at confirm.

### 4. Confirm — never spawn before asking

One `ask_user_question`, one single-select question per peer. Preview = condensed plain-text lines, one field per line:

```text
cwd:     <worktree or repo root>
branch:  <existing or proposed>
name:    <proposed peer name>
surface: pane | window | window:<session> | new-session:<name>
do:      <one-line work item>
paths:   <paths within cwd, relative>
merge:   <why one peer / separate>
```

`name` = registry name for `subagent_message` and `verify-peer.sh`. Derive it from the ticket id (exactly one in the item) else `gitName + worktree rel path`. Always pass it. User may edit name, branch, or surface at confirm.

Second option per question = Skip. Spawn confirmed peers only.

### 5. Worktree prep

Independent work needs its own worktree. From the repo cwd:

```bash
bash "$SKILL_ROOT/scripts/prepare-worktree.sh" <repo_cwd> <branch_name>
# prints WORKTREE=/abs/path
```

Branch exists → add `--existing`. Manual path:

```bash
wt switch -b @ -c <branch_name> | bash "$SKILL_ROOT/scripts/parse-worktree-path.sh"
```

Same checkout, no new worktree → pass the existing path as `cwd`.

### 6. Spawn — parallel calls

Batch independent spawns in one block. Pass `agent`, `task`, `name`, `cwd`, `surface`.

| Surface | Meaning |
|---------|---------|
| omit or `pane` | Pane split beside the caller |
| `window` | New window in the caller's tmux session |
| `window:<session>` or `<session-name>` | New window inside that existing tmux session |
| `new-session:<name>` | New detached tmux session |

Spawn returns at once with an acknowledgement. Do not wait, do not poll, do not tail session files. The harness delivers each peer result as a steer message.

### 7. Steer and resume

- Running peer → `subagent_message` with the peer name. Steering returns at once.
- Finished peer → `subagent_message` with the same name resumes it. Result arrives later as a steer message.

Optional read-only probe, on request:

```bash
bash "$SKILL_ROOT/scripts/verify-peer.sh" [--wait N] [--lines N] <peer-name>
```

Prints `PI=running|not-running`, `CWD`, `PROMPT=`, `MODEL`, `TASK` plus the pane tail. Exit 0 running · 3 not running within `--wait` (default 5, `0` = single check) · 1 bad target. Bare session name spans all its windows.

### 8. Echo

Per peer, print:

```
- **Task**: <title>
- **tmux**: <surface> — `sesh connect <worktree>`
- **worktree/branch**: <path> @ <branch>
- **name**: <registry name>
```

No gates on peers, no follow-up. Parent keeps working.

## Error handling

| Failure | Action |
|---------|---------|
| Not in tmux | Stop, user runs inside tmux |
| `lean-ctx` shell blocked | `bash "$SKILL_ROOT/scripts/..."` via top-level `bash`, not inline `$()` |
| `wt switch` fails | Show stderr; `wt list` |
| Can't parse worktree path | Re-run parser; else ask user for the path |
| Surface rejected | Check the agent's `surfaces` field. Removed surface values are hard errors — use `window` or `new-session:<name>` |
| Session name taken | User edits name at confirm, or pick `new-session:<name>` |
| Spawn error result | Read the tool result text; fix the field it names; respawn |
| `verify-peer.sh` exit 3 | pi not up within `--wait`; pane tail + `CWD` printed — raise `--wait` or attach |
| Unchanged re-spawn | Registry name exists → steer that peer instead of spawning a twin |

## Example

```
/parallel-work the two follow-up fixes you listed
```

1. tmux gate passes
2. Last response had fix A (auth module, existing worktree) + fix B (separate ticket)
3. Proposals: `NixConfig-auth` (`surface: window`, plain), `PRD-239` (`surface: new-session:PRD-239`)
4. `ask_user_question` — user drops A, edits B's branch
5. `prepare-worktree.sh <repo> PRD-239-…` → `WORKTREE=/Volumes/.../mono.prd-239-…`
6. `subagent { agent: "peer", name: "PRD-239", cwd: <worktree>, surface: "new-session:PRD-239", task: … }`
7. Echo surface, worktree, branch; `subagent_message` when the user wants a redirect
