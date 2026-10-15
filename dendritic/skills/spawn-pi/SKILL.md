---
name: spawn-pi
description: Fan out tmux pi workers — detached sessions (default) or new windows in the caller's session — for work named in the last agent response. Use when user says "spawn-pi", "spawn sessions for this", "fan out pi on this work", or points at continuation work from the last response to run in new sessions. Requires an active tmux session.
argument-hint: "[work item hint] — optional; rest extracted from last agent response"
---

# Spawn Pi

Spawn tmux pi worker(s) for continuation work found in the last agent response. Workers start detached (own session) or as a new window of the caller's session (`--in-window`). Parent stays alive after spawn — no `/quit`, no follow-up on workers.

## Skill root + scripts

Skill root = parent dir of this `SKILL.md`. Scripts committed under `scripts/` — **do not** write temp copies.

| Script | Purpose |
|--------|---------|
| `scripts/launch-worker.sh` | Spawn pi worker: detached session (default) or window in caller session (`--in-window`). Parent quit only when `PI_HANDOFF_QUIT=1` |
| `scripts/verify-worker.sh` | Read-only status probe for a spawned target (`session[:window]`): pi up, prompt executed, cwd/model/task. Never mutates tmux |
| `scripts/lib/pane-state.sh` | Sourced by launcher + verifier — pane introspection helpers, no side effects |
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
| `PI_ORCHESTRATOR_SNIPPET` | Snippet path override for `--orchestrator` (wins over built-in search) |

## Launcher interface

Flags precede positionals; positional order is unchanged.

| Pos | Meaning |
|-----|---------|
| 1 | `worktree_path` (required) — cwd the worker pi starts in |
| 2 | inline prompt — pass `''` together with `--prompt-file` |
| 3 | branch (report only, default `unknown`) |
| 4 | label/ticket (report only, default `unknown`; also feeds name auto-derive) |
| 5 | url or `''` (empty → report omits the URL line) |
| 6 | session name (detached) / window name (`--in-window`); omitted → auto-derived |

| Flag | Effect |
|------|--------|
| `--prompt-file <path>` | Prompt from file — **preferred**: no escaping, multi-line safe. Inline arg 2 wins nothing (WARN `inline prompt ignored`) |
| `--orchestrator` | Prepend `orchestrator-mode` snippet body; YAML frontmatter stripped inside the script |
| `--snippet <path>` | Snippet path override for `--orchestrator` |
| `--in-window` | New window in the caller's tmux session (`$TMUX`); detached session stays default |

Stdout keys the caller reads:

```text
SESSION=<session>          # detached: worker session; --in-window: caller's session
WINDOW=<session>:<window>  # --in-window only; full string is a valid tmux target
PROMPT=<submitted|unsubmitted|unknown|n/a>
```

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
mux:     detach (auto name) | window in this session
```

Second option per question = Skip (no spawn). Per-session skip keeps fan-out droppable. User may edit branch/prompt/mode/mux → apply before launch. Spawn only confirmed sessions.

### 5. Worktrees

If proposal has no worktree yet and is independent (multi-session fan-out, or user asked): create from the repo cwd:

```bash
wt switch -b @ -c <branch_name>
```

Branch exists → `wt switch <branch_name>`. Capture stdout+stderr, parse path:

```bash
bash "$SKILL_ROOT/scripts/parse-worktree-path.sh" <<<"$wt_output"
```

**Same checkout, no new worktree:** skip `wt switch` — pass the existing checkout path as `worktree_path` (arg 1). Worktree creation is for independent fan-out work only.

`test -d <path>` before launch (launcher does not validate the path itself).

### 6. Build prompt

Write the prompt to a file, launch with `--prompt-file` (preferred — no quoting or escaping to get wrong):

```bash
pf="${TMPDIR:-/tmp}/agent-tmp/spawn-pi/<session-name>.txt"
mkdir -p "$(dirname "$pf")"
printf '%s\n' '<lean task text + context params>' >"$pf"
```

Long/multi-line/heredoc prompts always go through a file. Inline arg 2 remains for short single-line text; the launcher itself auto-routes long, quoted, or multi-line prompts through a temp file and prints `PromptFile:` in the report.

Plain mode: lean task text + context params.

Orchestrator mode: append `--orchestrator`. The script resolves the snippet, strips its YAML frontmatter (`placement`/`order` are session-snippet plumbing), prepends the body verbatim, then the task text. **Never** concatenate the snippet or strip frontmatter by hand.

Snippet resolution order: `--snippet <path>` → `$PI_ORCHESTRATOR_SNIPPET` → `<repo>/dendritic/home-modules/pi-coding-agent/extensions/prompt-snippets/snippets/orchestrator-mode.md` → `~/.pi/agent/extensions/prompt-snippets/snippets/orchestrator-mode.md`. None found → exit 2.

### 7. Launch — parallel

One single shell invocation for all confirmed sessions — launches run in parallel, `wait`-gated (already verified independent; no ordering needed). **Arg 6 = explicit session name per launch** — workers never collide with the parent's pi or another busy session:

```bash
bash "$SKILL_ROOT/scripts/launch-worker.sh" --prompt-file "$pf_a" '<worktree_a>' '' "<branch_a>" "<label_a>" '' 'NixConfig.spawn-a' &
bash "$SKILL_ROOT/scripts/launch-worker.sh" --prompt-file "$pf_b" '<worktree_b>' '' "<branch_b>" "<label_b>" '' 'NixConfig.spawn-b' &
wait
```

`''` at arg 2 — `--prompt-file` supplies the prompt; positional order is unchanged. `tmux new-session -d` returns immediately. Non-zero from a launch = failure (pi not detected after the ~11s poll, or target not created → parent stays alive). Read the per-launch `SESSION=`/`WINDOW=`/`PROMPT=` lines.

**Window instead of detached session** (`mux: window` at confirm) — worker opens as a new window of the caller's session, next to the parent:

```bash
bash "$SKILL_ROOT/scripts/launch-worker.sh" --in-window --prompt-file "$pf_a" '<worktree_a>' '' "<branch_a>" "<label_a>" ''
```

Needs `$TMUX`; created with `tmux new-window -t <caller-session>: -n <name> -c <worktree>` and left selected (no `-d`). Explicit arg 6 naming an existing window: pi running there → WARN, prompt not sent; no pi → prompt sent into that window. Auto-derived names never land on an existing window (`-2` bump instead).

**Arg 6 omitted → name auto-derived**, in order:

1. Exactly one ticket id in prompt + label (`PI-239`, `PRD-239`, `[A-Z]{2,5}-<digits>`, non-ticket tokens like `SHA-256`/`UTF-8` skipped) → that id.
2. Else sesh-style `gitName + worktree rel path` (`NixConfig/dendritic…`); no repo root available → last two path components.
3. Name taken (detached: a pi runs in that session; `--in-window`: any window of that name exists) → suffix `-2`, `-3`…

Two or more ticket ids → `WARN: ambiguous ticket ids (…)`, falls back to the path-derived name. Override with arg 6 only on clash or ambiguity.

### 8. Echo

Done. Per session, print:

```
- **Task**: <title> — <mode>
- **tmux**: <session> (`sesh connect <worktree_path>`) — window mode: `<session>:<window>`
- **worktree/branch**: <path> @ <branch>
- **prompt**: first line of prompt — plus `PROMPT=<status>` when not `submitted`
```

Window targets: `WINDOW=<session>:<window>` is the tmux target as-is — split on the first `:` for the session half (`SESSION=` already holds it).

No gates on workers, no follow-up, parent keeps working. Optional read-only probe (before echo, or on demand) — never mutates tmux:

```bash
bash "$SKILL_ROOT/scripts/verify-worker.sh" [--wait N] [--lines N] [--marker-file "$pf"] <session[:window]>
```

Prints `PI=running|not-running`, `CWD`, `PROMPT=`, `MODEL`, `TASK` + pane tail. Exit 0 running · 3 not running within `--wait` (default 5, `0` = single check) · 1 bad target. `--marker-file` = the launcher's prompt file (or `--marker <text>`, ≥8 chars) → precise typed-but-unsubmitted probe; absent → pane/box heuristics. Bare session target spans all its windows (pi in any window ⇒ `PI=running`) — use `session:window` for one window.

## Error handling

| Failure | Action |
|---------|--------|
| Not in tmux | Stop, user runs inside tmux |
| `lean-ctx` shell blocked | `bash "$SKILL_ROOT/scripts/..."` via top-level `bash`, not inline `$()` |
| `wt switch` fails | Show stderr; `wt list` |
| Can't parse worktree path | Re-run parser; else ask user path |
| Propose branch name clash | User edits name at confirm; rerun switch |
| Confirm declined/dropped | Skip those sessions, no spawn |
| launch-worker non-zero | WARN from script + `SESSION=`/`WINDOW=` line + manual attach; parent alive |
| `--in-window` outside tmux | exit 2, `requires $TMUX` — caller not in tmux |
| Unknown flag / no prompt | exit 2 + usage message (`--prompt-file` unreadable → exit 2 too) |
| `--orchestrator` snippet missing | exit 2; set `$PI_ORCHESTRATOR_SNIPPET` or pass `--snippet <path>` |
| `--snippet` without `--orchestrator` | exit 2 — the snippet only applies in orchestrator mode |
| `new-window`/`new-session` fails | WARN + re-verify existence; ERROR exit 1 when target still absent |
| target already runs pi | Detached: launcher WARNs `already runs pi for a different task` + exits 0, prompt never sent (`PROMPT=n/a`) — pick fresh arg-6 name |
| prompt typed but unsubmitted | One `Enter` retry, then `WARN` + `PROMPT=unsubmitted` — attach, press Enter. Never loops |
| ambiguous ticket ids | `WARN: ambiguous ticket ids (…)` → path-derived name |
| `send-keys` → `can't find pane` | `=` prefix breaks target (names with `/`). Plain `"$session"` |
| `verify-worker.sh` exit 3 | pi not up in target within `--wait`; pane tail + `CWD` printed — attach, or raise `--wait` |

## Example

```
/spawn-pi the two follow-up fixes you listed
```

1. tmux gate passes
2. Last response had fix A (auth module, existing worktree) + fix B (separate tickets)
3. Proposals: session-fix-a (reuse checkout, plain, detached), session-fix-b (new worktree via wt, orchestrator, window)
4. `ask_user_question` — user drops session-fix-a, edits B's branch
5. `wt switch -b @ -c <branch>` for B → `parse-worktree-path.sh`
6. prompts written to `$TMPDIR/agent-tmp/spawn-pi/*.txt`
7. `launch-worker.sh --in-window --orchestrator --prompt-file …` → `WINDOW=caller:PRD-239`, `PROMPT=submitted`
8. Echo B's tmux target, worktree, branch, prompt; `verify-worker.sh caller:PRD-239` on request
