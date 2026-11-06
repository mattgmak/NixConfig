---
name: master-orchestrator
description: Run many Linear tickets in parallel through peer lanes, review, and merge. Use when the user says "orchestrate", "run the wave", or hands over a batch of tickets. The `update` argument is a sub-command. It rewrites this skill and runs no wave.
argument-hint: "[ticket ids or wave name] — Linear tickets to run, e.g. TECH-1424 TECH-1431 | update — rewrite this skill"
---

# Master Orchestrator

You plan, spawn, check, and merge. You read no source file. Every read, write, and test run goes to a lane. Your context stays small.

The argument decides the mode. `update` is a sub-command: it updates this skill and starts no wave. Any other argument is a wave of tickets. No argument asks the user which mode to run.

## Session shape

| Role | Who | Work |
|---|---|---|
| Orchestrator | you | plan, spawn, check facts, merge, report |
| Lane | `peer` subagent | one ticket: explore, write, gate, commit, push |
| Reviewer | `code-reviewer` subagent | one branch: standards plus spec |

One lane per ticket. A lane owns its worktree and its branch. You own the base branch and the merge order.

Completion criterion: you merge, block, or escalate every ticket in the wave with a reason.

## Grilling

The peer grills, never the master session. Read `reference/grilling.md`.

## Lane watch

Never poll, never sleep, never tail a log. The job holds the loop. Read `reference/lane-watch.md`.

## 1. Plan the wave

Read each ticket with the Linear MCP tool (`get_issue`). Take the id, title, state, and `gitBranchName`.

Set the ticket to In Progress and assign it to the user before the lane starts.

Order the wave by dependency. Record it in a todo list, one entry per ticket.

### Frontier board

The todo list is the frontier board. It shows what runs, what waits, and what blocks.

| Field | Content |
|---|---|
| subject | ticket id and title |
| status | pending, in progress or completed |
| blockedBy | the ticket ids that hold it |
| metadata | pull request number and lane name |

Update the board at four milestones: lane spawn, pull request open, review verdict, merge.

Mark a ticket in progress before its lane starts. Mark it completed right after its merge. Never batch a status change.

Refresh the board in the same turn as each merge, so the new frontier shows at once.

A ticket that leaves the frontier for a blocker carries `Backlog` on the board and in Linear.

## 2. Cut a worktree per ticket

Path: `/home/agent/drpom/tcm/tech-XXXX`. Branch: `gitBranchName` from Linear.

The wave names its base branch. Read it from the wave first. This repo uses `mattmak/meal-plan-agent`.

```bash
BASE=<base branch from the wave>
git fetch origin
git rev-parse origin/$BASE
wt switch -b @ -c <gitBranchName>
```

Run `bash ~/.pi/agent/skills/parallel-work/scripts/parse-worktree-path.sh` on the `wt` output when you need the path.

Reset the worktree to the base head before the lane starts. Base drift is normal. The base branch moves. Its history can change.

## 3. Spawn a lane

```text
subagent {
  agent:   "peer",
  name:    "lane-1424",
  cwd:     "<worktree path>",
  surface: "new-session:lane-1424",
  task:    "<lane brief>"
}
```

`peer` lists `surfaces: window, session`. A pane fails. A window dies with the parent. Always pass a dedicated session: `surface: "new-session:<name>"`, where `<name>` is the lane name. The user then finds each lane in its own tmux session.

The default profile is `peer`, in its own session. Only `peer` holds the full tool set: Linear, shell, the tracker and `ask_user_question`.

Use `worker` only for small work that opens no pull request. A `worker` lane loses the Linear tools, so paste the ticket text into its brief. Name the profile in every brief.

A `worker` lane that needs a pull request stops at once. Respawn it as `peer`.

Spawn returns at once. Do not poll, do not tail, do not sleep. The result arrives as a steer message.

### Model

Pass `model: "deepseek/deepseek-v4.1-flash-1017"` in every spawn, for lanes and reviewers alike. The model comes from OpenRouter. Do not rely on profile inheritance, because `~/.pi/agent/agents` is a read-only link into the Nix store. A model line written there is lost when home-manager runs.

This rule cascades. A lane passes the same model in each subagent it spawns. A lane also writes that rule into the brief of each child it spawns.

Add one line to every lane brief: `Pass model: "deepseek/deepseek-v4.1-flash-1017" in every subagent call you make.`

No lane limit applies. Spawn the next lane as soon as a ticket needs it.

### Peer decisions

A `peer` asks the user directly when a decision blocks the work. Call `ask_user_question` with two to four options, then wait for the answer.

The lane does not route that question through the orchestrator. It reports the answer, one line per decision.

A question names a decision, not a fact. Send a fact to a scout instead.

## 4. Lane brief

Every brief carries these fields:

| Field | Content |
|---|---|
| Profile | `peer`, or `worker` for small work with no pull request |
| Ticket | id, title, acceptance criteria |
| Base | base head sha |
| Worktree | path, branch, state |
| Rulings | decisions the user already made |
| Gates | the commands to run, in order |
| Report | head sha, changed files, exit code per gate |

Gate order. Give this exact list:

```bash
pnpm install
pnpm check-types
pnpm biome check --write <each changed file>
pnpm --filter <package> test
```

Rules to state in every brief:

- Paste the ticket text and its acceptance list into the brief. A lane reads the tracker with its own Linear tools, and the paste is the second source.
- Name the branch your pull request targets, when the branch is stacked.
- Commit with a subject only. No body, no trailers.
- Push the branch. Open one pull request against the base. Merge nothing.
- Run no simulator or device tooling. The orchestrator owns the evidence step.
- Name each surface the diff touches: a screen, a query, a mutation, or a schema table.
- Report the head sha, the changed files, and the exit code of each gate.

Completion criterion: the lane reports a head sha, a changed file list, and one exit code per gate.

## 5. Check the lane

Never trust a report alone. Check the cheap facts yourself:

```bash
git -C <worktree> rev-parse HEAD
git -C <worktree> status --porcelain
rg -n "<claim>" <worktree>/<path>
```

Run the failing gate yourself when an exit code looks wrong.

## 6. Chase an unfinished lane

A lane that says "gates running", "waiting", or "in progress" has not finished. Send the exact remaining steps and the report shape back:

```text
subagent_message { name: "lane-1424", message: "<remaining steps + report shape>" }
```

## 7. Review

Spawn `code-reviewer` on the branch when the lane lands. Point it at the worktree, the pull request and the ticket.

A `peer` reviewer is a defect. `code-reviewer` alone reviews. Send the spec source and a report path in the task.

A subagent that returns a provider error ends the wave. Report the error and start no replacement run. The user decides the next step.

`code-reviewer` allows one surface: `window`. A `new-session` call fails. Spawn it in a window.

```text
subagent { agent: "code-reviewer", name: "rev-1424", cwd: "<worktree>", surface: "window", task: "<PR number, base, ticket id, spec = Linear ticket, report path>" }
```

Send every fault back to the same lane with `subagent_message`. Name the file and the line. Repeat until the review passes.

Completion criterion: the review returns no blocking fault.

## 8. Merge

The default route is a pull request. You never merge on that route.

| Route | Trigger | Action | Who merges |
|---|---|---|---|
| 1. Pull request | the default for every wave | open a pull request on the lane branch, report the url, stop | the user, in the web interface |
| 2. Direct local merge | the user asks in the wave, in words such as "merge direct, no pull request" | merge and push the base | you |

Route 1 steps:

```bash
gh pr create --base $BASE --head <branch> --title "<ticket id>: <title>"
```

Route 2 steps:

```bash
git checkout $BASE
git merge --no-ff <branch>
git push origin $BASE
```

The shell policy denies `gh pr merge` and `gh pr close`. On route 1 the user merges in the web interface, so the denial does not block the wave.

Never take route 2 by default. Never take route 2 because a lane finished. Never mutate a pull request without an explicit request.

## PR checks and conflicts

A lane report is not a gate state. Read the three states by hand after every wake: checks, `mergeable`, unresolved threads. Read `reference/pr-gates.md`.

## 9. Keep moving

Do not wait for the user's merge gate. While a gate waits, stack the next branch and spawn the lanes that the merge unblocks.

### Stacking

One dependency level per stack. A three-deep chain waits for a user word. Read `reference/stacking.md`.

## 10. Unblock chain

After each merge, list the tickets that merge unblocks. Start their lanes in the same turn. Unstack every pull request that sat above the merged one.

Refresh the frontier board in that same turn. Read it back before you report, so every line matches the tracker.

Record the scope split in Linear when one ticket ships code and a second ticket ships data.

## 11. Scope discipline

A contract is a contract. Keep every band, cap, and gate as written. Report the failing numbers and stop. A contract change is a user call.

## 12. Base drift

```bash
git fetch origin
git -C <worktree> reset --hard origin/$BASE
```

Run install, types, and tests on the fresh base before you trust it.

## 13. Cleanup

After a merge, remove the worktree, delete the branch, and kill the lane session.

```bash
tmux kill-session -t lane-1424
```

A dirty worktree: save `git diff` and the untracked files under `/tmp/agent-tmp/<project>/patches/` first.

```bash
git -C <worktree> diff > /tmp/agent-tmp/<project>/patches/<branch>.diff
wt remove <branch>
git branch -D <branch>
```

The pull request landing is the trigger. Do not leave a session or a worktree behind.

## 14. Background gates

Run long gates with `ctx_bg`. Never poll. Never sleep. The result arrives as a message.

Write one line of status per phase change.

## 15. Tracker

Set the state at every lane milestone. Do not wait for the GitHub integration, and do not trust it alone.

| Milestone | Linear state | Extra |
|---|---|---|
| lane spawned | `In Progress` | assignee `me` |
| branch pushed, PR open | `In Review` | comment the PR url |
| PR merged | `Done` | comment the merge commit, the head sha, and the gate exit codes |
| lane blocked or parked | `Backlog` | comment the blocker |
| scope split | unchanged | one comment on each ticket |

Link the PR with `Fixes TECH-123` in the title only when the PR completes the ticket. Use `Refs TECH-123` for partial work.

After a merge, read the ticket back and confirm the state. A ticket that still sits at `In Progress` after its PR merged is a stale tracker.

## 16. Evidence gate

Every app UI change carries evidence before the review opens. One artifact per changed screen. Read `reference/evidence.md`.

## Remote iOS build

Builds run on the Mac mini, never on this host. Read `reference/macos-remote-build.md`.

## 17. Escalate

Ask the user only for these:

- a scope call
- a cost call
- an irreversible action
- a simulator or device run
- a change to a contract

Everything else runs without a question.

## 18. Voice

Reply terse. Use Simplified Technical English in every reply, comment, document, and commit message. A commit carries a subject only.

## Sub-commands

`update` rewrites this skill and starts no wave. `reflect` drafts changes from past sessions. Both need the user's approval before a write. Read `reference/subcommands.md`.
