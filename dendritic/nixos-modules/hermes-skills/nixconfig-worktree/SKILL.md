---
name: nixconfig-worktree
description: >
  Run a NixConfig change end to end. Use when Hermes starts or continues any
  NixConfig edit, from cron or chat. Hermes runs as the agent account, edits
  through pi-local in a worktrunk worktree, and hands the approval pane to the
  owner. Never runs the deploy itself.
---

# nixconfig-worktree (Hermes = agent → pi-local → owner gate)

Hermes runs as `agent`, so it owns the checkout and every worktree. No sudo
wrapper, no ACL grant, no `chown` repair. pi-local edits, the owner approves,
the script deploys. One worktree per task, one review session per worktree.

## Steps

| # | Step | Command |
| --- | --- | --- |
| 1 | Create the worktree | `wt switch --create <branch>` from `/home/agent/NixConfig`, then read the path (see Worktree) |
| 2 | Materialize submodules | `git -C <worktree> submodule update --init`, only when the change needs a checkout. Skip it for a nix-only change and pass `--flake` in step 5 |
| 3 | Delegate the edit | `pi-local -p "<brief>" > <worktree>/../.pi-brief.out` (see the `pi` skill) |
| 4 | Commit | `git -C <worktree> commit -m "<subject>"`. The agent git config carries the owner identity |
| 5 | Verify | `bash scripts/host-sandbox.sh ramsay --tier build --flake "git+file:///home/agent/NixConfig?ref=refs/heads/<branch>"` |
| 6 | Open the review session | `spawn-approval-session <branch> --worktree <path>` builds the three panes |
| 7 | Hand over | reply with the session name and the command waiting in the approval pane. The owner presses Enter |
| 8 | After the deploy | the script sends the result into the pi pane, on success and on failure |

## Worktree

`wt` names the directory `/home/agent/NixConfig.<branch>`. Read the path from
the JSON list instead of guessing it:

```sh
wt -C /home/agent/NixConfig switch --create fix-ramsay-agenix
wt -C /home/agent/NixConfig list --format json |
  jq -r '.[] | select(.branch=="fix-ramsay-agenix") | .path'
```

A fresh worktree has empty submodule directories, so every nix eval of its path
fails until they exist. `git submodule update --init` clones every submodule
from its URL, because git does not reuse the main checkout's git dirs. One dead
URL stops the whole update, and the clones can land on commits that differ from
the index. Then `wt merge` commits that dirt into main. For a nix-only change,
skip the update and point the check at the branch instead:

```sh
--flake "git+file:///home/agent/NixConfig?ref=refs/heads/<branch>"
```

The agent account owns the tree, so no `chown` and no mode fix ever comes back.
Never edit `/home/agent/NixConfig` itself for a task, and never edit a worktree
another task owns.

## Delegate

Write the brief with the rules in the `pi` skill: one task, the full context, no
follow-up questions in print mode. The brief names the worktree path, the files
in scope, and the check to run. Ask for one deliverable: the change summary the
owner reads, in the reply body.

pi-local writes files with its own tools. When it cannot write, Hermes saves the
summary to `<worktree>/PI-SUMMARY.md`.

Every commit in a NixConfig worktree is `mattgmak <u3592095@connect.hku.hk>`.
The agent account gets that identity from `/home/agent/.config/git/config`, so
a plain `git commit` carries it. The `-c user.name=... -c user.email=...` form
is only for accounts outside agent.

## Review session

`spawn-approval-session` builds the session, and the agent account runs it
directly. The session lives on the agent tmux server, so the owner sees it
beside the `NixConfig` and `agents` sessions. The package lives in
`dendritic/packages/spawn-approval-session.nix`.

```sh
spawn-approval-session fix-ramsay-agenix \
  --worktree /home/agent/NixConfig.fix-ramsay-agenix
```

Pass `--force` to replace a session that already exists. Every pane runs its
program through an interactive zsh, so `/home/agent/.config/zsh` loads.

| Window | Pane | Content |
| --- | --- | --- |
| `work` | 1 | `pi-local` interactive session, running at open |
| `work` | 2 | `l` (lazygit) on the worktree, running at open |
| `work` | 3 | interactive zsh with the approval command prefilled, no `Enter` |

One window holds all three panes, and the layout matches the agent layout in
`AGENTS.md`. Only the approval pane waits for the owner. The script keeps the
pane, because the session belongs to the owner.

When `tmux` reports `error connecting ... (No such file or directory)`, the
agent server is not running. The agent account has no live session. Ask the
owner. Never start a server for another account.

## After the gate

| Result | Hermes action |
| --- | --- |
| Deploy passed | The script sends the handoff into the pi pane. Kill the session only when the owner asks. |
| Deploy failed | The script stops and keeps its output on screen. Resume the pi pane with the failure text and the log path, so pi-local continues the fix in the same worktree. |
| Owner wants changes | Send the new brief into the pi pane. The worktree stays until the next approval. |

```sh
tmux -S $S send-keys -t "$pi_pane" -l \
  'Deploy failed. Read <log path>, fix the cause, then report the result.'
```

## Never

- Run `approve-and-deploy.sh` from a Hermes tool call. The owner presses Enter.
- Run `wt merge` by hand. The script owns the merge.
- Reuse a worktree for a second task. One branch, one worktree, one session.
- Delete a worktree that still holds an unapproved commit.
- Edit `/home/agent/NixConfig` itself, or a worktree another task owns.
- Use `sudo` for `wt`, `pi-local`, or `spawn-approval-session`. The agent
  account runs all three without it.
- Write a `HANDOFF.md`. The pi session and the script handoff carry the context.
