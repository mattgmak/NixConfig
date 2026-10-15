---
name: spawn-pi
description: Fan out new detached tmux pi sessions for work named in the last agent response. Use when user says "spawn-pi", "spawn sessions for this", "fan out pi on this work", or points at continuation work from the last response to run in new sessions. Requires an active tmux session.
argument-hint: "[work item hint] — optional; rest extracted from last agent response"
---

# Spawn Pi

Spawn detached tmux pi worker(s) for continuation work found in the last agent response. Parent stays alive after spawn — no `/quit`, no follow-up on workers.

## Skill root + scripts

Skill root = parent dir of this `SKILL.md`. Scripts committed under `scripts/` — **do not** write temp copies.

| Script | Purpose |
|--------|---------|
| `scripts/launch-worker.sh` | Detached tmux + pi worker. Parent quit only when `PI_HANDOFF_QUIT=1` |
| `scripts/lib/parent-quit.sh` | Sourced by launcher — not invoked alone |
| `scripts/parse-worktree-path.sh` | `wt switch` output → absolute worktree path |

Resolve skill root at runtime (pick one that exists):

```bash
SKILL_ROOT="${PI_SKILL_ROOT:-$HOME/.pi/agent/skills/spawn-pi}"
# NixConfig dev: SKILL_ROOT="$(git rev-parse --show-toplevel)/dendritic/skills/spawn-pi"
```

## Env flags

| Var | Effect |
|-----|--------|
| `PI_HANDOFF_QUIT=1` | Deferred parent `/quit` after worker up (spawn-pi never sets this) |
| `PI_HANDOFF_QUIT_DELAY` | Quit delay seconds, default 2 |
| `PI_REPORT_FILE` | Handoff report path, default `${TMPDIR:-/tmp}/agent-tmp/agent-handoff-report.txt` |

## Workflow

### 0. Tmux gate — before everything

**Completion criterion:** `$TMUX` non-empty, or stopped.

```bash
[ -n "${TMUX:-}" ] && echo in-tmux
```

Unset → stop. Tell user to run inside tmux. No summaries, no worktrees, no parsing before this check.

### 1. Extract work items

Optional arg names which items count ('all' when absent). Read the last agent response (session history). Each item → proposal:

- **Task text**: lean summary of the item (worker explores from here — no response chunks embedded verbatim)
- **Context params**: repo / worktree / paths / branch / Linear-or-GitHub ticket, wherever the response ties the work to them. Work tied to an existing checkout → reuse it; no branch → propose a name (ticket/activity-derived) for user edit
- **Mode**: orchestrator or plain.

**Orchestrator heuristic** (shown in summary): touches >1 area, uncertain scope, multi-path or multi-session fan-out → orchestrator. One confined fix with clear path → plain.

**Completion criterion:** every continuation item in the last response is either a proposal, merged into one, or explicitly excluded with the user's reason. No silent drops.

### 2. Independence check — merge or split

Agent judgement:

- Same repo + overlapping paths/branches/ticket → **merge** into one session.
- Disjoint repos/worktrees/tickets/paths → **split**.

The confirm flow catches mistakes — when unsure, split rather than merge, user merges back at confirm.

### 3. Cap

Hard cap 3 concurrent spawned sessions per invocation. Above cap → merge proposals or ask user which to drop.

### 4. Confirm — never spawn before asking

One `ask_user_question`, **one single-select question per session**. Preview rules:

- Options carry `preview` — only renders on single-select, so no multiSelect here.
- Preview = condensed plain-text lines, one per field (markdown tables cut off in previews):

```text
cwd:     <full path the worker pi starts in — worktree/repo root>
branch:  <existing or proposed>
do:      <one-line work item>
paths:   <paths within cwd, relative>
mode:    plain | orchestrator
merge:   <why one session / separate>
mux:     auto (sesh-style from worktree)
```

Second option per question = Skip (no spawn). Per-session skip keeps fan-out droppable. User may edit branch/prompt/mode — apply before launch. Spawn only confirmed sessions.

### 5. Worktrees

If proposal has no worktree yet and is independent (multi-session fan-out, or user asked): create from the repo cwd:

```bash
wt switch -b @ -c <branch_name>
```

Branch exists → `wt switch <branch_name>`. Capture stdout+stderr, parse path:

```bash
bash "$SKILL_ROOT/scripts/parse-worktree-path.sh" <<<"$wt_output"
```

`test -d <path>` before launch.

### 6. Build prompt

Plain mode: lean task text + context params.

Orchestrator mode: prepend the full `orchestrator-mode.md` text inline to the prompt. Copy verbatim from:

`dendritic/home-modules/pi-coding-agent/extensions/prompt-snippets/snippets/orchestrator-mode.md`

Falls back to `~/.pi/agent/extensions/prompt-snippets/snippets/orchestrator-mode.md` if project path absent. Read once per invocation, prepend to each orchestrator-classified prompt. Frontmatter of that file (`placement`/`order`) is session-snippet plumbing — drop it from the prompt copy; only the body goes into the quoted prompt string.

Single-quote the prompt; escape embedded single quotes as `'\''`.

### 7. Launch — parallel

One single shell invocation for all confirmed sessions — launches run in parallel, `wait`-gated (already verified independent; no ordering needed). **Arg 6 = explicit session name per launch** — workers never collide with the parent's pi or another busy session:

```bash
bash "$SKILL_ROOT/scripts/launch-worker.sh" 'worktree_a' 'prompt_a' "branch_a" "label_a" "" "NixConfig.spawn-a" &
bash "$SKILL_ROOT/scripts/launch-worker.sh" 'worktree_b' 'prompt_b' "branch_b" "label_b" "" "NixConfig.spawn-b" &
wait
```

Passing `""` to arg 5 (it's `<url-or-empty>`): report omits URL line. `tmux new-session -d` returns immediately. Non-zero from a launch = failure (pi not detected after ~11s poll → parent stays alive). Read the per-launch `SESSION=` lines.

### 8. Echo

Done. Per session, print:

```
- **Task**: <title> — <mode>
- **tmux**: <session> (`sesh connect <worktree_path>`)
- **worktree/branch**: <path> @ <branch>
- **prompt**: first line of prompt
```

No gates on workers, no follow-up, parent keeps working.

## Error handling

| Failure | Action |
|---------|--------|
| Not in tmux | Stop, user runs inside tmux |
| `lean-ctx` shell blocked | `bash "$SKILL_ROOT/scripts/..."` via top-level `bash`, not inline `$()` |
| `wt switch` fails | Show stderr; `wt list` |
| Can't parse worktree path | Re-run parser; else ask user path |
| Propose branch name clash | User edits name at confirm; rerun switch |
| Confirm declined/dropped | Skip those sessions, no spawn |
| launch-worker non-zero | WARN from script + `SESSION=` line + manual attach; parent alive |
| target session already runs pi | Launcher WARNs `already runs pi for a different task` + exits 0, prompt never sent — pick fresh arg-6 name |
| `send-keys` → `can't find pane` | `=` prefix breaks target (names with `/`). Plain `"$session"` |

## Example

```
/spawn-pi the two follow-up fixes you listed
```

1. tmux gate passes
2. Last response had fix A (auth module, existing worktree) + fix B (separate tickets)
3. Proposals: session-fix-a (reuse checkout, plain), session-fix-b (new worktree via wt, orchestrator)
4. `ask_user_question` — user drops session-fix-a, edits B's branch
5. `wt switch -b @ -c <branch>` for B → `parse-worktree-path.sh`
6. `launch-worker.sh` with orchestrator snippet prepended
7. Echo B's tmux session, worktree, branch, prompt
