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

The user grills in a peer. The orchestrator never runs an interview round in its own session.

A grill round here floods the context with decisions that belong to the wave. It also breaks the base rule: the orchestrator reads no source file and writes no prose.

Spawn a `peer` with a brief that names the tickets. The peer uses `ask_user_question` for each round and waits for the answers. The peer reports the settled decisions, one line per ticket.

Then the orchestrator starts the wave and treats those decisions as rulings.

| Do | Do not |
|---|---|
| spawn `peer` for the grill | ask a numbered question round here |
| pass the tickets and the open facts | ask the user for a fact a scout can find |
| take the settled rulings into the wave | hold the wave until the grill ends |

## Lane watch

One `ctx_bg` job watches each open lane. Name the job `lane-watch #<pr>`.

```text
ctx_bg {
  name:    "lane-watch #152",
  command: "bash ~/NixConfig/dendritic/skills/master-orchestrator/watch-lane.sh 152 DrPOM-Medical/tcm 3000",
  wake_on: "^(FOUND|CONFLICT|MERGED|CLOSED) ",
  timeout_ms: 3300000
}
```

The script prints one state line first, then exits. Read the line and act.

| Line | Meaning | Action |
|---|---|---|
| `STANDING n` | unresolved threads at start | sweep them before you trust a clean gate |
| `FOUND n` | new unresolved CodeRabbit threads | send each thread to its lane: file, line, fault, fix |
| `CIFAIL` | a check turned to `fail`, or a watched pull request starts red | read the failing job, give its lane the error line |
| `CONFLICT` | `mergeable` reads CONFLICTING | send the rebase steps |
| `MERGED` | the pull request merged | unstack, sweep, set the ticket to Done |
| `CLOSED` | closed with no merge | ask the user |
| `RATE_LIMIT` | CodeRabbit reports a limit | note the limit. The watch keeps looking for `MERGED` and `CONFLICT`. The line does not wake you |
| `TIMEOUT` | no new state inside the window | report the pull request at the gate |

Every state exits 0, because a merge is the result and not a fault. Only an unreadable pull request exits 1 with an `ERROR` line.

Rules:

- Start one watch when the first lane opens a pull request, and add each later number to the list.
- A merged pull request leaves the list. Start the job again with the rest.
- Restart the watch after each lane push that resolves threads.
- Read the three gate states by hand after a wake. The line is a trigger, not a verdict.
- Never poll by hand, never sleep, never tail a log. The job holds the loop.
- A `MERGED` line starts the cleanup turn. Unstack the pull requests above it, remove the worktree, kill the lane session, and set the ticket to Done.
- The script window is 3000 s and `timeout_ms` is 3300000. The job limit of 60 minutes kills a longer window, so keep the window under it.
- A job that exits 124 hit its job limit. Start the watch again with a fresh window.
- A job id can expire and leave its process running. Before a restart, clear the process and check the count.
- Clear a watcher with a bracket pattern: `pkill -f 'watch-lanes[.]sh'`. A plain pattern matches the command line of the shell that runs it, and the shell then kills itself with exit 143.
- The shell policy denies a pipe to `xargs`. Kill with `pkill` alone, and read the count with `pgrep -cf 'watch-lanes[.]sh'`.
- A lost job reports `not found or expired` and holds no result. Read the three gate states by hand, then start a fresh watch with `unique: true`.
- `ctx_bg` reuses the id of an identical command. So an expiry message can name an earlier instance. Run `status` on the id before a restart, and pass `unique: true` on a start so each watch holds its own id.

`watch-coderabbit.sh` stays for a CodeRabbit-only watch. `watch-lane.sh <pr>` covers one pull request. `watch-lanes.sh` covers the whole wave with one job.

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

Every lane uses `peer`. A lane on any other profile is a defect, because only `peer` holds the full tool set: Linear, shell and the tracker. `worker` drops the Linear tools, so the lane cannot read its own ticket. Respawn such a lane, and paste the ticket text into the new brief.

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

A pull request at the gate holds three states. Read all three. A lane report is not one of them.

```bash
gh pr checks <pr>
gh pr view <pr> --json mergeable,mergeStateStatus
gh api graphql -f query='{repository(owner:"DrPOM-Medical",name:"tcm"){pullRequest(number:<pr>){reviewThreads(first:50){nodes{isResolved}}}}}' --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)]|length'
```

| Result | Action |
|---|---|
| a check reads `fail` | run `gh run view <run-id> --log-failed`, name the failing job and test, send it to the lane |
| `mergeable` reads CONFLICTING | send the rebase steps: fetch, rebase onto the base head, take the delete on a deleted file, force-push with `--force-with-lease`. A stacked branch rebases onto its new base, not onto the old lower branch |
| the thread count is above zero | run the CodeRabbit loop |
| all pass, MERGEABLE, zero threads | report the gate |
| the body holds no `## Evidence` or `## Verification` block, and the diff touches UI, Convex code, or app logic | send the evidence brief from section 16 |

Rules for a red check:

- A green local gate with a red CI run is a failed lane. Say so in the message.
- Send the failing job, the test name, and the run url. Never send the whole log.
- The `ci` check runs the turbo pipeline. Its error names a task, for example `tcm-app#test:unit`. Pass the task name to the lane.

Rules for a stale artifact or a moved base:

- Re-read all three states after every lane push. A fix can turn one green and another red.
- A generated artifact stale against new data fails a repo test. Tell the lane to run the generator that the test runs. Never edit the test.
- The base moves. A pull request that read MERGEABLE an hour ago can read CONFLICTING now.

## 9. Keep moving

Do not wait for the user's merge gate. While a gate waits, stack the next branch and spawn the lanes that the merge unblocks.

### Stack a dependent branch

A lower pull request waits at the gate. A higher ticket needs its code. Stack the higher branch on the lower branch head. Do not hold the higher lane.

```bash
git fetch origin <lower-branch>
git -C <worktree> reset --hard origin/<lower-branch>
gh pr create --base <lower-branch> --head <higher-branch> --title "<ticket id>: <title>"
```

Name the chain in Linear on both tickets. Write the chain bottom first, for example `#152 <- #160`.

Rules:

- One dependency level per stack. A three-deep chain waits for a user word.
- A reviewer reads the diff against the lower branch. Call that verdict provisional.
- Only the bottom pull request names `mattmak/meal-plan-agent` as its base.

### Unstack after a merge

The lower pull request lands. Retarget and rebase the higher branch in the same turn.

The `MERGED` line from the lane watch starts this step. Do not wait for a lane report.

```bash
git fetch origin
git -C <worktree> rebase origin/mattmak/meal-plan-agent
git -C <worktree> push --force-with-lease
gh pr edit <pr> --base mattmak/meal-plan-agent
```

Then run the lane gates, spawn a fresh review on the new diff, and read all three gate states. A provisional verdict does not carry.

### Fix a conflict

1. Read both sides. Name the fact each side adds.
2. Keep the union. Never take one side blind, and never drop another ticket's work.
3. Where the two sides disagree on a rule, stop and escalate. A conflict is not a licence to change a contract.
4. Run the gates after the resolve.
5. Force-push with `--force-with-lease`.

## 10. Unblock chain

After each merge, list the tickets that merge unblocks. Start their lanes in the same turn. Unstack every pull request that sat above the merged one.

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

## 16. UI and sandbox evidence

A pull request that changes app UI carries visual proof. A pull request that changes Convex backend code or app logic carries sandbox proof. Never open the review without it.

Every app UI change carries evidence before the review opens. A small change takes no exception: a badge, a chip, or a copy line still needs one artifact per changed screen.

Capture it from the real app on a leased simulator, built on the mini. Publish it on the pull request as a release asset shown inline. A pull request without that block waits at the gate, and the body names the missing artifact.

| Change | Evidence |
|---|---|
| static element, layout, or copy | one screenshot per changed state |
| dynamic or behaviour change | one clip of 20 seconds or less |
| Convex schema, query, mutation, or action | one sandbox run that exercises the change, with its result |
| app logic without a visible surface | one sandbox run that shows the new value or path |
| both UI and logic | every artifact above |

An evidence run reuses the dev client already on the simulator when its native fingerprint matches the tree. Build only on a mismatch. The method sits in `reference/macos-remote-build.md`.

Steps for UI:

1. Ask the user before the first simulator command. The repo forbids an automatic run.
2. Start the sandbox and read the origin rule in `docs/agents/sandbox.md`.
3. Lease a simulator from the manzanas fleet. Install the dev client. Launch the app.
4. Drive the screens with `argent` on the leased device. Record the trigger twice: before and after.
5. Keep a working copy under `/tmp/agent-tmp/<project>/evidence/<ticket>/` while you capture.
6. Publish every artifact on the pull request. Never commit an evidence file into the repository unless the ticket asks for a tracked file. Upload it as a pull request attachment or a release asset, and link it from the body.
7. Publish motion as an animated GIF. A body gives no player. The renderer strips a `<video>` tag, and an mp4 inside an image tag shows a broken image. A GIF plays inline and loops.
8. Add an `## Evidence` block to the body. Name the artifact, the screen, and the proof it gives. The block holds no local path and no untracked file name.

Steps for backend and app logic:

1. Start the sandbox on the lane branch: `pnpm sandbox:up`. Read the status output before you trust it.
2. Seed a participant through the sandbox tools. Use the onboarding fixture, not a hand-made row.
3. Run the changed path. Call the query, send the mutation, or open the screen that reads it.
4. Capture the request, the response, and the stored document. Save the log or the screenshot under `/tmp/agent-tmp/<project>/evidence/<ticket>/`.
5. Add a `## Verification` block to the body. State the command or tap path, the observed result, the sandbox id, and one exit code per gate.
6. Stop the sandbox and say so in the report.

Rules:

- The proof shows the real app on a real simulator, against the real sandbox. A mock or a web build is a defect.
- Replace every network identifier with a placeholder such as `sandbox-host` or `simulator-1`.
- A clip keeps the dish, the value, or the state on screen long enough to read.
- A pull request without proof waits at the gate. Name the missing artifact.
- A green unit test does not replace the sandbox run. Say which claim the run settles.
- Release the lease and stop the sandbox after the capture.
- A reviewer reads the proof in the pull request, with no clone. An uploaded image renders inline, and a release asset opens on one click. A clip too large to upload gets a link beside its key frames.
- Each changed screen gets its own artifact. One screenshot of a screen that did not change proves nothing.
- An evidence file stays out of the repository. Commit one only when a ticket names it as a tracked artifact.
- Keep each uploaded image small. Shrink a clip with `ffmpeg` before the upload, and keep the value or the dish name readable.
- A GIF stays under 10 MB at about 420 pixels wide. Confirm the frame count, and confirm one frame shows the action. A frame the eye cannot read is no proof.
- A person can reach one route that code cannot: the web editor turns a dropped clip into an inline player. Probe `POST https://api.github.com/user-attachments/assets` and expect 404. No `gh api` call creates an attachment, and a release asset gives no player. Ask the user when a true player is needed.
- The GIF is the default. It needs no session, no account, and no click. Offer the player route once, then ship the GIF.
- When the app must run, build it on the mini and read `reference/macos-remote-build.md` first.

## Remote iOS build

The app builds on the Mac mini, never on this Linux host. Read `reference/macos-remote-build.md` before the first command.

A lane needs two facts before it starts:

- Run `pnpm install --ignore-scripts`. The `uniwind-pro` postinstall needs a token, so the scripted install fails.
- Every path sits under `/Volumes/Kingston480GB/tcm-build/`: `repo`, `DerivedData`, `store`, `logs`, `artifacts`, `npm-global`.

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

## Sub-command: reflect

`/skill:master-orchestrator reflect` studies past subagent sessions and drafts skill changes. It starts no lane, opens no pull request, and touches no ticket.

Steps:

1. Spawn one `peer` on this repo. Give it the files to read: the most recent subagent sessions that this skill spawned. Default is 10 sessions. The user can name a count, a ticket or a date range.
2. Ask the peer for waste and for traps:
   - a lane that rebuilt a dev client
   - a lane that reported a gate it never ran
   - a brief that left a fact to guess
   - a watch that lapsed
   - a retry after a provider error
   - a proof no reviewer could read
   - a reviewer that mirrored the code under test
3. Ask for a table: finding, example, proposed change, target file, section. One example per finding, and it names the session file, the ticket and one short quote.
4. Send the user the table, one row per change. Wait for the word.
5. Apply only the approved rows. Write no line before that word.
6. Report each section you changed and each row you dropped, with its reason.

Rules:

- One finding needs one example. A change with no example stays a guess.
- A draft may touch `SKILL.md` and `reference/`. It touches no ticket and no code.
- The approval rule holds in every loop: `reflect`, `update`, and the fold of a single correction. Never write this skill before the user agrees.

## Sub-command: update

`/skill:master-orchestrator update` is a sub-command. It rewrites this file. It starts no lane, opens no pull request and touches no ticket.

Steps:

1. Read this file and the corrections from the last wave.
2. Fold each correction into the section it belongs to. Keep the section order and the voice.
3. Show the user the proposed change, section by section. Wait for approval.
4. Write the file after approval, and never before. This holds in every loop, including a mid-wave correction. Report each section you changed.
5. Leave a rule in place when the user rejects it, and say why it stays.

A wave session learns a new step, a new gate or a dead rule. Fold it into the file in the same turn. Do not hold a correction for the next update.

Ask the user first, every time.

Path: `dendritic/skills/master-orchestrator/SKILL.md`. Spawn a peer on `~/NixConfig` when the edit touches more than two sections.
