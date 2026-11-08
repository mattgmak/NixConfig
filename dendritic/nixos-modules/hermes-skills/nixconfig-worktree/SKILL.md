---
name: nixconfig-worktree
description: >
  Run a NixConfig change end to end. Use when Hermes starts or continues any
  NixConfig edit, from cron or chat. Delegates the edit to pi-local, opens the
  NixConfig-<branch> tmux review session on the agent server, and hands the
  approval pane to the owner. Never runs the deploy itself.
---

# nixconfig-worktree (Hermes → pi-local → owner gate)

Hermes writes nothing in the main checkout. pi-local edits, the owner approves, the script deploys. One worktree per task, one review session per worktree.

## Steps

| # | Step | Command |
| --- | --- | --- |
| 1 | Create the worktree | `wt -C /home/agent/NixConfig switch --create <branch>` |
| 2 | Materialize submodules | `git -C <worktree> submodule update --init` |
| 3 | Delegate the edit | `pi-local -p "<brief>" > <worktree>/../.pi-brief.out` (see the `pi` skill) |
| 4 | Write the handoff doc | `<worktree>/HANDOFF.md` |
| 5 | Open the review session | `tmux -S /run/user/1000/tmux-1000/default new-session -d -s NixConfig-<branch>` |
| 6 | Fill the session | one window for lazygit, one window split between pi-local and the approval pane |
| 7 | Hand over | reply with the session name and the command waiting in the approval pane |
| 8 | After the deploy | resume the pi-local pane with the result, then update `HANDOFF.md` |

## Worktree

The branch name comes from the task: `fix-ramsay-agenix`. The worktree path comes from `wt`:

```sh
wt -C /home/agent/NixConfig switch --create fix-ramsay-agenix
wt -C /home/agent/NixConfig list --format json |
  jq -r '.[] | select(.branch=="fix-ramsay-agenix") | .path'
```

`wt` names the directory `/home/agent/NixConfig.<branch>`. A fresh worktree has empty submodule directories, so every nix eval fails until `git submodule update --init` runs there. The main checkout holds the submodule git dirs, so the update needs no download.

Never edit `/home/agent/NixConfig` itself, and never edit a worktree another task owns.

## Delegate

Write the brief with the rules in the `pi` skill: one task, the full context, no follow-up questions in print mode. The brief names the worktree path, the files in scope, and the check to run.

Ask for two deliverables in the brief:

1. The change summary the owner reads, in the reply body.
2. The handoff doc content: state, next steps, and the exact deploy command.

pi-local writes files with its own tools. When it cannot write, Hermes saves the summary to `<worktree>/PI-SUMMARY.md`.

## Handoff doc

Write `<worktree>/HANDOFF.md` after every pi-local run, before the approval pane opens. The file is the memory of the worktree: the next pi-local run reads it instead of guessing.

```markdown
# HANDOFF fix-ramsay-agenix
Owner: hermes   Worker: pi-local   Branch: fix-ramsay-agenix
Worktree: /home/agent/NixConfig.fix-ramsay-agenix

## Brief
<the exact brief text>

## State
<summary from pi-local, plus git status --porcelain>

## Run log
| When | Action | Result |
| --- | --- | --- |
| 2026-11-08T21:04 | pi-local run 1 | exit 0, 2 files changed |
| 2026-11-08T21:31 | approve-and-deploy | exit 0, main now 0acb3d8 |

## Next
<what the next run must do, or "nothing: waiting for owner approval">

## Deploy command
scripts/approve-and-deploy.sh fix-ramsay-agenix --caller <pi-pane-id> --no-kill
```

Keep the file in the worktree, so it merges into `main` with the change and the history keeps it.

## Review session

The session lives on the agent tmux server, so the owner sees it in the same list as the `NixConfig` and `agents` sessions.

```sh
S=/run/user/1000/tmux-1000/default
tmux -S $S new-session -d -s NixConfig-fix-ramsay-agenix -c <worktree> -n lazygit lazygit
pi_pane=$(tmux -S $S list-panes -t NixConfig-fix-ramsay-agenix:lazygit -F '#{pane_id}' | head -1)
```

The first window holds `lazygit` on the worktree. Rename it, then build the second window with two panes:

```sh
tmux -S $S rename-window -t NixConfig-fix-ramsay-agenix:0 review
tmux -S $S new-window -d -t NixConfig-fix-ramsay-agenix -n work -c <worktree>
approve_pane=$(tmux -S $S split-window -h -p 45 -P -F '#{pane_id}' \
  -t NixConfig-fix-ramsay-agenix:work -c <worktree>)
```

Window `work` pane 1 runs pi. Pane 2 holds the approval command. Prefill both with `send-keys -l` and no `Enter`, so nothing runs until the owner presses it:

```sh
tmux -S $S send-keys -t "$pi_pane" -l \
  'pi-local -p "Read HANDOFF.md and give me the change summary for this worktree."'
tmux -S $S send-keys -t "$approve_pane" -l \
  'cd <worktree> && scripts/approve-and-deploy.sh fix-ramsay-agenix --caller '"$pi_pane"' --no-kill'
```

Pass `--no-kill`: the session belongs to the owner, so the script must keep the pane. The `pi` pane is the `--caller`, so the verification prompt lands in the session, not in a Hermes window.

## Owner access

Two layers gate the agent tmux server, and the skill needs both:

1. The directories. `logind` makes `/run/user/1000` mode `0700`, so `hermes` cannot traverse it. The rule `A+ /run/user/1000 - - - - u:hermes:r-x` in `dendritic/hosts/Ramsay.nix` puts a POSIX ACL on the runtime dir and everything under it, including `tmux-1000`.
2. The socket. `agent` runs `tmux -S /run/user/1000/tmux-1000/default server-access -a hermes`. It changes the socket from `srw-------` to `srwxrwx---`. Only the server owner or root can run it, so the agent runs it, never `hermes`.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `error connecting ... (Permission denied)` | No ACL on the runtime dir | Wait for the switch, or ask the agent to run `server-access` |
| `error connecting ... (No such file or directory)` | No tmux server: `agent` never logged in | Ask the owner. Never start a server as `hermes` |
| `ambiguous target` on `server-access` | The `-S` socket was missing from the command | Always pass `-S <path>`, not `$TMUX` |

- The owner attaches as `agent`: `tmux attach -t NixConfig-fix-ramsay-agenix`.
- The approval command uses the absolute sudo paths written in the `deploy` skill. A bare `sudo ramsay-deploy-switch` misses the sudoers rule and stalls on a password prompt.

## After the gate

| Result | Hermes action |
| --- | --- |
| Deploy passed | The script sends the verify prompt into the pi pane. Add the result row to `HANDOFF.md`. Kill the session only when the owner asks. |
| Deploy failed | The script stops and keeps its output on screen. Resume the pi pane with the failure text and the log path, so pi-local continues the fix in the same worktree. |
| Owner wants changes | Send the new brief into the pi pane. The worktree stays until the next approval. |

```sh
tmux -S $S send-keys -t "$pi_pane" -l \
  'Deploy failed. Read HANDOFF.md and <log path>, fix the cause, then update HANDOFF.md.'
```

## Never

- Run `approve-and-deploy.sh` from a Hermes tool call. The owner presses Enter.
- Run `wt merge` by hand. The script owns the merge.
- Reuse a worktree for a second task. One branch, one worktree, one session.
- Delete a worktree that still holds an unapproved commit.
- Start a pi session as root or as `hermes` for review work. The review pi runs as `agent`.
