---
name: master-orchestrator
description: Run many Linear tickets in parallel through peer lanes, review, and merge. Use when the user says "orchestrate", "run the wave", or hands over a batch of tickets. The `update` argument is a sub-command. It rewrites this skill and runs no wave.
argument-hint: "[ticket ids or wave name] — Linear tickets to run, e.g. TECH-1424 TECH-1431 | update — rewrite this skill"
---

# Master Orchestrator

You plan, spawn, check, and merge. You read no source file. Every read, write, and test run goes to a lane. Your context stays small.

The argument decides the mode. `update` is a sub-command: it updates this skill and starts no wave. `rush [on|off]` is a sub-command: it sets the gate mode and starts no wave. Any other argument is a wave of tickets. No argument asks the user which mode to run.

## Session shape

| Role | Who | Work |
|---|---|---|
| Orchestrator | you | plan, spawn, check facts, merge, report |
| Lane | `peer` subagent | one ticket: explore, write, gate, commit, push |
| Reviewer | `code-reviewer` subagent | off by user ruling on 2026-11-12. Read section 7 |

A lane is always `peer`. No exception covers work with no pull request. A lane runs verification, a device check, or a one-off test as `peer` too. `worker` is not a lane.

One lane per ticket. A lane owns its worktree and its branch. You own the base branch and the merge order.

Completion criterion: you merge, block, or escalate every ticket in the wave with a reason.

## Grilling

The peer grills, never the master session. Read `reference/grilling.md`.

One exception: in `work-mode=direct` the master session grills. Read `## Work mode`.

## Lane watch

Never poll, never sleep, never tail a log. The job holds the loop. Read `reference/lane-watch.md`.

## Review threads

Every reviewer thread needs an answer before a pull request merges. CodeRabbit leaves inline comments. A lane replies to each thread it addresses, in the same pull request.

Reply shape: one or two sentences. Name the fix and the commit sha. Never restate the comment. Never paste a diff. A thread that needs no change gets one line that gives the reason.

Example reply: "Addressed in f1583e73. `bout_seconds_of` rejects a non-digit, a zero, and an empty list before the builder writes a row."

Add one line to every lane brief: `Reply to each CodeRabbit inline comment in one short reply. Name the fix and the commit sha.`

The orchestrator checks the open threads before it reports a ticket at the gate. Run `gh api` on the review comments, list the unresolved ones, and chase them by lane.

A pull request reaches the gate with no open thread. After a lane answers a thread and the fix lands, resolve that thread.

```bash
gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'
```

A thread that needs no change gets a reply that gives the reason. Leave that thread open only
when the user ruling is the record, and name it in the gate report.

Read the open thread count before you report a ticket at the gate. A non-zero count holds the
pull request.

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

A merged ticket leaves the board. Show open work only: pending, in progress, and blocked.
A report may name a merge in one line. The board holds no completed row.

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

The default profile is `peer`, in its own session. `peer` holds the full tool set: Linear, shell, the tracker and `ask_user_question`.

`worker` is never a lane. A `worker` allows the `pane` and `window` surfaces only, so a `new-session` call fails before the lane starts. A `worker` lane also loses the Linear tools. Reserve `worker` for a child a lane spawns for small work. Name the profile in every brief.

Spawn returns at once. Do not poll, do not tail, do not sleep. The result arrives as a steer message.

### `cwd`

Pass `cwd` as the lane's own worktree path. Never pass the base worktree path.

A lane spawned in the base tree works by `cd` before every command. One forgotten `cd` then edits the base branch. A lane resumed with `subagent_message` keeps the `cwd` of its first spawn, so the first call decides.

Read the path from the `wt` output, or from `bash ~/.pi/agent/skills/parallel-work/scripts/parse-worktree-path.sh`.

### Model

Pass `model: "balance/deepseek-v4.1-flash"` in every spawn, at every level. That covers a lane, a reviewer, and a child a lane spawns. The model comes from OpenRouter. Do not rely on profile inheritance, because `~/.pi/agent/agents` is a read-only link into the Nix store. A model line written there is lost when home-manager runs.

This rule cascades. A lane passes the same model in each subagent it spawns. A lane also writes that rule into the brief of each child it spawns.

Add one line to every lane brief: `Pass model: "balance/deepseek-v4.1-flash" in every subagent call you make, at every level.`

No lane limit applies. Spawn the next lane as soon as a ticket needs it.

### Peer decisions

A `peer` asks the user directly when a decision blocks the work. Call `ask_user_question` with two to four options, then wait for the answer.

The lane does not route that question through the orchestrator. It reports the answer, one line per decision.

A question names a decision, not a fact. Send a fact to a scout instead.

## 4. Lane brief

Every brief carries these fields:

| Field | Content |
|---|---|
| Profile | `peer` always. A lane never runs as `worker`. |
| Ticket | id, title, acceptance criteria |
| Base | base head sha |
| Worktree | path, branch, state |
| Rulings | decisions the user already made |
| Gates | the commands to run, in order |
| Evidence | the artifacts a UI or logic change needs, with the screen name |
| Report | head sha, changed files, exit code per gate, evidence artifact |

Say the gate list once. A steer that resumes a lane names only the step that changed, and no lane re-reads a list it already holds.

A brief names the ticket, the ruling and the gate. A later steer names the delta.

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
- Name each surface the diff touches: a screen, a query, a mutation, or a schema table.
- A diff that touches an app screen carries device evidence before the pull request opens. The lane captures it on a leased simulator and publishes it on the pull request. Read `reference/evidence.md`.
- The device ladder decides the capture device. A leased iOS simulator on the mini is the default. The Android emulator on this host is the fallback, and it applies when the fleet does not answer. Name the device in the Evidence block.
- A lane drives the iOS simulator itself through the manzanas MCP tools. It asks nothing. Read `reference/evidence.md`.
- A lane asks the user before an emulator fallback, because that device differs from the shipped platform.
- A diff with no screen and no visible value carries no simulator evidence. Say so in the report.
- Report the head sha, the changed files, one exit code per gate, and the evidence artifact.
- Run a long command in the foreground: `ctx_shell` with `timeout` 900 or more. Never end a turn to wait for anything.
- Several long commands at once need one `worker` subagent per command, each with a foreground call. The lane waits for them. `ctx_bg` is the master's tool, never a lane tool.
- A lane that spawns its own subagents passes no model override. The default model applies at every level.
- A provider rate limit is not a failure. Wait, retry the same call with a growing pause, and keep the worktree so a retry resumes. Report the exact error string only after a retry fails.
- Run `scripts/gate-cache.sh` once per head, and read the cache in every later turn. Read `reference/agent-loop.md`.
- Reply once per phase in three lines, and put the six report fields in the file from `scripts/lane-report.sh`. A command result inside a phase earns no reply.

Completion criterion: the lane reports a head sha, a changed file list, one exit code per gate, and each evidence artifact the change needs.

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

One steer per phase. A second miss means the lane is wrong for the work. Stop it, save the tree, and spawn a fresh lane with a narrower brief. A lane that runs past 60 minutes gets a narrowed brief, not a nudge. Read `reference/agent-loop.md`.

A lane that idles on a background job gets one foreground command that blocks, and no reply before it returns.

## 7. Review

Review spawn is off by user ruling on 2026-11-12. Do not spawn `code-reviewer`. A lane reports its own gate exits. The user reviews in the web interface. Restore the block below when the user asks.

A lane spawns no reviewer either. The rule covers the master session and every child it starts, so a lane that wants a second pair of eyes reports the doubt instead of spawning one.

CodeRabbit threads arrive from the GitHub App, not from this flow. The `code-review` flag does not reach it. A reply to a CodeRabbit thread follows the rule in `## Review threads`.

<!-- Review flow, off by user ruling on 2026-11-12.

Spawn `code-reviewer` on the branch when the lane lands. Point it at the worktree, the pull request and the ticket.

A `peer` reviewer is a defect. `code-reviewer` alone reviews. Send the spec source and a report path in the task.

A subagent that returns a provider error ends the wave. Report the error and start no replacement run. The user decides the next step.

`code-reviewer` allows one surface: `window`. A `new-session` call fails. Spawn it in a window.

```text
subagent { agent: "code-reviewer", name: "rev-1424", cwd: "<worktree>", surface: "window", task: "<PR number, base, ticket id, spec = Linear ticket, report path>" }
```

Send every fault back to the same lane with `subagent_message`. Name the file and the line. Repeat until the review passes.

Completion criterion: the review returns no blocking fault.

-->

## 8. Merge

The default route is a pull request. You never merge on that route.

Rush mode changes when you wait, and never who merges. Read `## Rush mode`.

### Gate waiver

The user can rule out the wait at the gate. The words are "no need to wait for my gate".
Then rush mode reads on, and you keep working.

The route stays the same. The pull request waits at the gate for the user. You cut the next
branch from the waiting branch head. You open its pull request against that branch. You spawn
its lane at once. You merge nothing.

After the user merges, retarget the branch above it and rebase it in the same turn.

| Route | Trigger | Action | Who merges |
|---|---|---|---|
| 1. Pull request | the default for every wave | open a pull request on the lane branch, report the url, stop | the user, in the web interface |
| 2. Direct local merge | `work-mode=direct`, or the user asks in the wave in words such as "merge direct, no pull request" | merge and push the base | you |

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

Never take route 2 in `work-mode=standard`. Never take route 2 in `direct` mode because a lane finished. Never mutate a pull request without an explicit request.

`work-mode=direct` selects route 2 with no per-wave request. Read `## Work mode`. A pull request merge stays a user action in both modes.

## PR checks and conflicts

A lane report is not a gate state. Read the three states by hand after every wake: checks, `mergeable`, unresolved threads. Read `reference/pr-gates.md`.

Every pull request targets `mattmak/meal-plan-agent`. Read `reference/pr-base.md` before you open or report one.

## 9. Keep moving

Rush `on`: do not wait for the user's merge gate. Stack the next branch and spawn the lanes that the merge unblocks.

Rush `off`: report the pull request and wait. The user merges before the next ticket starts.

## Rush mode

Rush is one state toggle for the whole session. The default state is `off`.

| State | Rule | Stacking |
|---|---|---|
| `off` | report the pull request, then wait for the user merge | none. The next ticket starts after the merge |
| `on` | push past the gate and keep working | one dependency level per stack |

Switch the state with `rush on` or `rush off`. `rush` alone reports the state and changes nothing.

In both states you merge nothing. The user merges in the web interface.

In rush `on`, do these steps after each pull request:

1. Cut the next branch from the waiting branch head.
2. Open the pull request against the waiting branch, not the base.
3. Write the chain in Linear on both tickets, bottom first.
4. Spawn the next lane at once.

After the user merges the lower pull request, retarget and rebase the upper branch in the same turn. Read `reference/stacking.md`.

Rush keeps every other gate. Run the review, the evidence gate and the full gate list. Escalate the same five calls.

A three-deep chain waits for a user word in both states.

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

`ctx_bg` is the master's tool only. The master runs it, ends the turn, and messages the lane the result. A lane that runs `ctx_bg` ends its turn, the pane closes, and the job dies.

A lane runs a long gate in the foreground: `ctx_shell` with `timeout` 900 or more. Read `reference/agent-loop.md`.

Never poll. Never sleep. Write one line of status per phase change.

## 15. Tracker

Set the state at every lane milestone. Do not wait for the GitHub integration, and do not trust it alone.

These steps belong to `standard`. A `direct` change writes no Linear record.

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

The lane captures the evidence, not the orchestrator. A UI brief names each changed screen, and the lane publishes one artifact per screen. Before you spawn the review, read the pull request body and confirm the `## Evidence` block holds the artifacts. A pull request without the block waits, and you send the capture steps back to the lane.

A lane runs `scripts/preflight-evidence.sh` before the first capture, and pastes its four checks. A `FOREIGN` line names another checkout, so the device proves nothing.

`work-mode=direct` is the one exception: the lane captures its own Android still with no ask, and the still serves no review. Read `## Work mode`.

### Simulator access

A lane leases its own target through the manzanas MCP server. It asks no permission.

| Step | Tool |
|---|---|
| see the fleet | `manzanas_targets` |
| claim a target | `manzanas_lease_acquire` with `labels: ["ios26"]`, then keep `lease_id` |
| install and launch the app | `manzanas_app` |
| read the screen | `manzanas_ui_tree` |
| tap, type, scroll | `manzanas_tap_element`, `manzanas_type_into_element`, `manzanas_scroll_to_element` |
| wait, never sleep | `manzanas_wait_for_element`, `manzanas_wait_tree_stable` |
| capture a still | `manzanas_screenshot` |
| export the run journal | `manzanas_journal_export` with `run_id` = `lease_id` |
| free the target | `manzanas_lease_release` |

Rules:

- The lane renews a lease before `ttl_seconds` runs out, and releases it before the report.
- A lane prefers an element matcher over a screen coordinate. A raw `manzanas_tap` needs the reason.
- A lane reads each still and states what it sees before it publishes.
- Two lanes share no target. Each lane leases its own.
- A failing fleet names the error string in the report. The lane then asks the user before it tries the Android emulator.

### Device ladder

The iOS simulator is the default device. It is not the only one.

| Order | Device | Condition |
|---|---|---|
| 1 | leased iOS simulator on the mini | always try this first |
| 2 | Android emulator on this host | the fleet does not answer, or it returns a black frame |
| 3 | no device | name the gap in the body, and file a ticket |

A fallback names four facts in the body: the reason with the fleet error string, the device as
`android-emulator:<avd>`, the bundle check, and the Metro url. Read `reference/evidence.md` for
the detection signals and the preflight commands.

### Where the evidence lives

One route publishes evidence: `gh pr edit <pr> --attach <file>`. It mints a `user-attachments`
asset and appends the image to the body. The repository keeps no evidence file.

Never use a release asset, a committed file, a raw URL, or an outside image host.

You need `gh` 2.99.0 or later. `scripts/publish-evidence.sh <pr> <folder>` does the uploads.

Write the body text first, then attach last. `gh pr edit --body` replaces the whole body, so a text edit after an attach drops every image.

Read the body back after the attach. A block without a `user-attachments` url fails the gate.

A pull request whose `## Evidence` block holds a release link fails the gate. Send it back.

### A follow-up that changes a proven surface

A follow-up prompt can change a surface that the body already shows. That stale artifact is a
defect, because the reviewer reads proof of older code.

1. Recapture every artifact whose surface the follow-up changed.
2. Remove the stale image from the body, and attach the new one.
3. Name the new head sha beside each artifact.

A block that names an older head than the pull request fails the gate. Send it back to the lane.

An unchanged surface keeps its artifact. Do not recapture a screen that the follow-up did not touch.

## Remote iOS build

Builds run on the Mac mini, never on this host. Read `reference/macos-remote-build.md`.

## 17. Escalate

Ask the user only for these:

- a scope call
- a cost call
- an irreversible action
- an Android emulator or physical device run, because the lane leases an iOS simulator itself
- a change to a contract

Everything else runs without a question.

## 18. Voice

Reply terse. Use Simplified Technical English in every reply, comment, document, and commit message. A commit carries a subject only.

## State flags

Three flags live in one file: `rush`, `code-review`, and `work-mode`. The path is
`/tmp/agent-tmp/tcm/master-orchestrator-state-flag`. Each line reads `name=value`.

Read the file at session start, before a gate report, and after each wake. A missing file means
`rush` and `code-review` read off, and `work-mode` reads `standard`.

Use `scripts/state-flag.sh`. No argument prints every flag. `get <name>` prints one value.
`set <name> <value>` writes one value. The `MASTER_ORCHESTRATOR_FLAG` variable overrides the path.

`rush` and `code-review` take `on` or `off`. `work-mode` takes `direct` or `standard`. The
`work-mode` flag picks the flow per change. Read `## Work mode`.

The `rush` flag decides the wait at the gate. `on` keeps the wave moving and stacks the next
branch. `off` stops at the reported pull request.

The `code-review` flag decides the review spawn. `off` means a lane reports its own gate exits,
and the user reviews in the web interface.

## Work mode

The `work-mode` flag picks the flow for each change. The default is `standard`.

| Mode | Flow per change |
|---|---|
| `standard` | Linear ticket, worktree, lane, branch push, pull request, user merge |
| `direct` | spec in chat, worktree, one lane, local `--no-ff` merge, push |

### standard

Unchanged from today. Read sections 1 to 15. Plan a Linear ticket per change, cut a worktree, and
spawn a lane. Push the branch and open a pull request against `mattmak/meal-plan-agent`. The user
merges.

### direct

This mode serves a rapid UI tweak. Take no step that the merge does not need.

This mode is the one exception to `## Grilling`. The master session asks the short questions
itself, because no ticket carries the spec. Keep the exception narrow: one short round, then spawn.

Per change:

1. Ask the short clarifying questions in this session. Wait for the answers.
2. Cut a worktree with `wt switch --create <branch>`, then spawn one `peer` lane.
3. The lane edits, runs the full gate list, and commits on its own branch.
4. Merge with route 2 of `## 8. Merge`, then remove the worktree, kill the lane session, and
   report one line.

A `direct` change writes no Linear record, opens no pull request, and spawns no review. Read
section 13 for the removal and the kill.

Evidence: in `direct` mode a lane captures its own still on the Android emulator of this host,
with no user ask. The still serves visual verification, not a review gate. The lane looks at the
still, states what it sees, and fixes a fault before it reports.

- Route: the dev server of the lane worktree, plus the AVD on this host. Read the **Metro port**
  rule in `## Sandbox dev`. Each worktree gets its own port, and `dev:mock` passes it as
  `TCM_METRO_PORT`.
- Still path: `/tmp/agent-tmp/tcm/evidence/<change>/`. The repository keeps no evidence file.
- `work-mode=standard` keeps the current rule: the lane leases its own iOS simulator through manzanas, and the still goes on the pull
  request.
- Devices: a leased iOS simulator still needs the user ask, in both modes. A change that touches a
  native path still needs a device run that the user approves.

A `direct` lane owns its own sandbox and its own stills.

- The lane starts the sandbox and the dev server for its own worktree, then stops them before it
  reports.
- The lane reads its own Metro port from `pnpm sandbox:status`, as the **Metro port** rule says. It
  never stops the Metro of another worktree.
- The lane boots the AVD it needs and captures the stills itself. It reads each still and fixes a
  fault before it reports.
- The lane stops the sandbox it started. It leaves no service behind.
- `work-mode=standard` keeps the old rule: a lane runs neither action.

The gate list does not change. A direct merge runs `pnpm check-types`, `pnpm biome check --write`,
and the package tests before it merges.

Out of scope: a change that edits a schema, a backend mutation, or a native path. Route that change
to `standard`.

## Sub-commands

`update` rewrites this skill and starts no wave. `reflect` drafts changes from past sessions. Both need the user's approval before a write. Read `reference/subcommands.md`.

`rush [on|off]` sets the `rush` flag. It reads the state with no argument. The default is `off`.

`code-review [on|off]` sets the `code-review` flag. It reads the state with no argument. The
default is `off`, by user ruling on 2026-11-12.

`work-mode [direct|standard]` sets the `work-mode` flag. It reads the state with no argument and
changes nothing. The default is `standard`. Read `## Work mode`.

`sandbox-dev up` starts the sandbox and a dev server in the tmux session `sandbox-dev`. Read `## Sandbox dev`.

`sandbox-dev reset` clears the sandbox data, then seeds fresh rows. Read `## Sandbox dev`.

## Sandbox dev

`sandbox-dev up` starts the sandbox and a dev server in a new tmux session. `sandbox-dev reset` clears the sandbox data and seeds fresh rows. Neither action changes this skill. Read `docs/agents/sandbox.md` and `docs/agents/sandbox-tailscale.md` first.

Both actions use a worktree of the tcm monorepo. This skill documents the commands. A lane runs neither action on its own, except a `work-mode=direct` lane, which runs both for its own still.

### `sandbox-dev up`

The session is `sandbox-dev`. Its first window is `dev`, and that window runs the dev server. The worktree root is the working directory.

```bash
export SANDBOX_LAN=1
export SANDBOX_PUBLIC_ORIGIN=sandbox-host
tmux new-session -d -s sandbox-dev -n dev -c "$PWD" 'pnpm dev:mock'
tmux attach -t sandbox-dev:dev
```

`sandbox-host` is the bare tailnet host name. The repository prints no host name, so the operator supplies it. Add no scheme and no port, because `parsePublicOrigin` adds `http://` (`scripts/sandbox/common.ts:111`). The name must resolve on the tailnet, or the phone cannot reach Metro.

`pnpm dev:mock` runs the full chain. The root script reads `sandbox:status`, starts the sandbox when it is down, then runs `scripts/sandbox/dev-mock.ts`. That script starts `pnpm --filter tcm-app dev:mock -- --host lan`. The app script is `TCM_AUTH_MODE=mock EXPO_NO_DOTENV=1 expo start --dev-client --clear --port $TCM_METRO_PORT` (`apps/tcm-app/package.json:96`).

A public origin also sets `REACT_NATIVE_PACKAGER_HOSTNAME` to the host (`scripts/sandbox/metro-command.ts:28-30`). Metro then prints the tailnet host in its QR line and deep link:

```
Metro: exp+easy-tcm://?__expo_url=http%3A%2F%2F<host>%3A<metroPort>
```

Without the setting, Metro prints the LAN address and a plain `pnpm dev` on the host keeps its default.

Do not write `pnpm dev:mock --filter tcm-app`. The root script passes no filter, and the extra argument reaches `tsx`. The chain sets the filter itself (`scripts/sandbox/metro-command.ts:20`).

**Metro port.** The supervisor reserves five ports at startup and records them in `state.json`. Each worktree gets its own port, and `dev:mock` passes it as `TCM_METRO_PORT`. Read the port with `pnpm sandbox:status`.

A stale process on the Metro port means one action: wait. `pnpm dev:mock` waits for the port itself. Never stop the Metro of another worktree. Never give the app a different port by hand.

**Phone step.** Open the dev-client launcher and tap `Enter URL manually`. Type `<host>:<metroPort>`, for example `sandbox-host:44981`. Add no scheme, because the launcher adds `http://`.

The full deep link reads `easy-tcm://expo-development-client/?url=http%3A%2F%2F<host>%3A<metroPort>` (`docs/agents/envy-android-emulator.md:100`). Send that link with `adb shell am start` on Android.

The tailnet address reaches the phone because Expo runs with `--host lan` (`scripts/sandbox/metro-command.ts:21-23`). Metro then binds every interface. The phone on the same tailnet resolves the bare host name and reaches the port.

`turbo.json:114` lists `REACT_NATIVE_PACKAGER_HOSTNAME` for the `dev` task. The `dev:mock` chain skips Turbo, so the chain sets the variable itself from `SANDBOX_PUBLIC_ORIGIN`.

**Failure.** `up` fails with exit code 1. Read the log path that the command prints, then run `pnpm sandbox:status`. Do not start a second `dev:mock`.

### `sandbox-dev reset`

```bash
pnpm sandbox:reset
```

The command stops the sandbox and clears the Convex deployment directory of this worktree. It then starts the services, pushes the functions, and seeds data (`docs/agents/sandbox.md`, command table).

`pnpm sandbox:seed` replaces the mock auth data and the seeded rows with no wipe (`docs/agents/sandbox.md`, command table). Use it when a stale row only needs fresh values.

Three guards keep the reset local. The CLI call clears the deployment selector with `CONVEX_DEPLOYMENT: ""` (`scripts/sandbox/convex-cli.ts:20`). It sets `CONVEX_SELF_HOSTED_URL` to the local `state.convexUrl`. No script passes `--prod`. `wipeDeployment` refuses a path that is not a plain directory (`scripts/sandbox/common.ts:206-207`).

**Failure.** `reset` fails with exit code 1. Read the log, run `pnpm sandbox:status`, then retry once. Do not delete the deployment directory by hand.

### Local emulator (Android, this host)

Use this route when a still or a manual check comes from the emulator of this host. It needs no tailnet name and no public origin. Drop `SANDBOX_LAN` and `SANDBOX_PUBLIC_ORIGIN` for this route.

Boot the AVD in a real tmux window. Never boot it with `ctx_bg`, because that job dies with the turn. The window keeps the process and shows the boot log.

```bash
tmux new-window -d -t sandbox-dev -n emu -c "$PWD" \
  "ANDROID_HOME=$SDK ANDROID_SDK_ROOT=$SDK emulator -avd <avd> \
   -no-snapshot-save -gpu swiftshader_indirect -no-audio \
   -no-boot-anim 2>&1 | tee /tmp/agent-tmp/tcm/emulator.log"
```

`$SDK` is the sdk path in `apps/tcm-app/android/local.properties`. The tmux server carries no `ANDROID_HOME`, so the emulator stops with `FATAL | Cannot find AVD system path` when the prefix is absent.

Wait for the boot in one blocking command:

```bash
adb wait-for-device && adb shell \
  'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done; echo booted'
```

The emulator reaches the sandbox through `adb reverse` on each loopback port. Read the ports from `pnpm sandbox:status`, then run one rule per port. The app needs the Metro port, the Convex port, the HTTP actions port, the tongue backend port and the mock Clerk port.

```bash
for p in <metroPort> <convexPort> <sitePort> <backendPort> <issuerPort>; do
  adb reverse tcp:$p tcp:$p
done
```

Then start the app on the Metro url:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "exp+easy-tcm://expo-development-client/?url=http%3A%2F%2F127.0.0.1%3A<metroPort>"
```

An emulator restart drops every rule. Apply them again before the next capture.

Tap the mock-auth fixture in the app when the bundle lands. A cold start returns to the sign-in screen.
