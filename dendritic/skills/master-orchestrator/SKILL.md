---
name: master-orchestrator
description: Run many Linear tickets in parallel through peer lanes, review, and merge. Use when user says "orchestrate", "run the wave", "master orchestrator", hands over a batch of tickets, or asks for parallel lanes with review and merge gates.
argument-hint: "[ticket ids or wave name] — Linear tickets to run, e.g. TECH-1424 TECH-1431"
---

# Master Orchestrator

You plan, spawn, check, and merge. You read no source file. Every read, write, and test run goes to a lane. Your context stays small.

## Session shape

| Role | Who | Work |
|---|---|---|
| Orchestrator | you | plan, spawn, check facts, merge, report |
| Lane | `peer` subagent | one ticket: explore, write, gate, commit, push |
| Reviewer | `code-reviewer` subagent | one branch: standards plus spec |

One lane per ticket. A lane owns its worktree and its branch. You own the base branch and the merge order.

Completion criterion: you merge, block, or escalate every ticket in the wave with a reason.

## Grilling

The user grills in a peer. The orchestrator never runs an interview round in its own session.

A grill round here floods the context with decisions that belong to the wave. It also breaks the base rule: the orchestrator reads no source file and writes no prose.

Spawn a `peer` with a brief that names the tickets. The peer uses `ask_user_question` for each round and waits for the answers. The peer reports the settled decisions, one line per ticket.

Then the orchestrator starts the wave and treats those decisions as rulings.

| Do | Do not |
|---|---|
| spawn `peer` for the grill | ask a numbered question round here |
| pass the tickets and the open facts | ask the user for a fact a scout can find |
| take the settled rulings into the wave | hold the wave until the grill ends |

## CodeRabbit loop

Run this loop after a lane opens a pull request.

1. Start the watch with `ctx_bg`. The timeout is 20 minutes:

```bash
bash ~/NixConfig/dendritic/skills/master-orchestrator/watch-coderabbit.sh <pr> DrPOM-Medical/tcm 1200
```

2. The script exits on one of four states: `FOUND` new unresolved threads, `RATE_LIMIT`, `TIMEOUT`, or `CLOSED`.
3. On `FOUND`, send each thread to the lane: file, line, fault, and the fix. The lane fixes, gates, pushes, and resolves the thread. Start the watch again.
4. On `RATE_LIMIT`, stop the loop. Report the limit to the user.
5. On `TIMEOUT`, the pull request holds no new CodeRabbit thread. Report it at the gate.
6. Never poll by hand. The script holds the loop.

## 1. Plan the wave

Read each ticket with the Linear MCP tool (`get_issue`). Take the id, title, state, and `gitBranchName`.

Set the ticket to In Progress and assign it to the user before the lane starts.

Order the wave by dependency. Record it in a todo list, one entry per ticket.

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

Spawn returns at once. Do not poll, do not tail, do not sleep. The result arrives as a steer message.

## 4. Lane brief

Every brief carries these fields:

| Field | Content |
|---|---|
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

- Commit with a subject only. No body, no trailers.
- Push the branch. Open no pull request. Merge nothing.
- Run no simulator or device tooling.
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

Spawn `code-reviewer` on the branch when the lane lands. Point it at the worktree and the Linear ticket.

```text
subagent { agent: "code-reviewer", name: "review-1424", cwd: "<worktree>", surface: "window", task: "<branch, base, ticket id>" }
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

## 9. Keep moving

Do not wait for the user's merge gate. While a gate waits, rebase and stack the next branch. Spawn the lanes that the merge unblocks in the same turn.

## 10. Unblock chain

After each merge, list the tickets that merge unblocks. Start their lanes in the same turn.

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

Keep the wave todo list current. Set each ticket to Done in Linear with a comment. The comment names the pull request url, or the merge commit on route 2, and the evidence.

## 16. Escalate

Ask the user only for these:

- a scope call
- a cost call
- an irreversible action
- a simulator or device run
- a change to a contract

Everything else runs without a question.

## 17. Voice

Reply terse. Use Simplified Technical English in every reply, comment, document, and commit message. A commit carries a subject only.

## Keep this skill current

The workflow changes. When the conversation shows a new step, a new gate, or a dead rule, this skill is stale.

You may spawn a peer on `~/NixConfig` to update this skill.

Ask the user first, every time. Show the proposed change before the peer writes it. Wait for approval.

Path: `dendritic/skills/master-orchestrator/SKILL.md`.
