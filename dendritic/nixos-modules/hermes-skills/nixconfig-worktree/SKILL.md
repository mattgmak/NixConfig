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
| 5 | Open the review session | `sudo -n /run/current-system/sw/bin/spawn-approval-session <branch> --grant hermes` |
| 6 | Fill the session | the same command builds all three panes. Pass `--worktree <path>` when the directory name differs from the branch |
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

### Ownership

`/home/agent` has no setgid bit, so a new directory takes the primary group of its creator. `agent` makes `agent:users 2775`. `hermes` makes `hermes:hermes 2770` with `0600` files, and the agent tmux server cannot enter it.

Only agent may create the worktree. `AGENTS.md` gives worktree management to agent, and hermes cannot undo its own mode:

- The hermes sudoers rule allows one command, `/run/current-system/sw/bin/ramsay-deploy-switch` (`dendritic/nixos-modules/hermes.nix`). `sudo chown` asks for a password hermes does not have.
- The agent rule allows `ALL` with `PASSWD`, so `sudo chown` prompts there too.
- A non-root user cannot change files another user owns.

When a hermes-created worktree already exists, the owner runs these commands as root:

```sh
chown -R agent:users /home/agent/NixConfig.<branch>
chmod g+rwx /home/agent/NixConfig/.git/worktrees/NixConfig.<branch>
```

`wt` makes the admin directory mode `0700`, so `git worktree list` stays broken until the `chmod` runs. Check the result with `stat -c '%U:%G %a' <worktree>` and `test -r <worktree>/.git`.

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

`spawn-approval-session` builds the session. The package lives in
`dendritic/packages/spawn-approval-session.nix`, and hermes has one `NOPASSWD`
rule for it in `dendritic/nixos-modules/hermes.nix`. The script re-executes
itself with `runuser -u agent`, so the session comes from the agent account even
when hermes runs it through `sudo`. It passes `PATH`, `HOME`, `USER`, and
`ZDOTDIR` to `new-session`, so every pane gets the agent environment. A session
made straight from a hermes shell takes the hermes `PATH`: no `delta`, no
`lazygit`, and the `pi-local` from `pkgs.piLocalHermes`.

```sh
sudo -n /run/current-system/sw/bin/spawn-approval-session fix-ramsay-agenix --grant hermes
```

Pass `--worktree` when the directory name differs from the branch, and `--force`
to replace a session that already exists:

```sh
sudo -n /run/current-system/sw/bin/spawn-approval-session bump-pi-1.1.7 \
  --worktree /home/agent/NixConfig.bump-pi-1.1.5 --force --grant hermes
```

Every pane runs its program through an interactive zsh, so
`/home/agent/.config/zsh` loads. A bare `tmux new-session ... lazygit` execs the
program with no shell, so no rc file loads. The `exec` at the end of each command
keeps the pane open after the program exits. The script names every target with
the colon form `"$session:"`. The dots in `NixConfig-bump-pi-1.1.7` otherwise
make tmux read session `NixConfig-bump-pi-1` plus pane `1.7`, and the error is
`can't specify pane here`.

| Window | Pane | Content |
| --- | --- | --- |
| `review` | 1 | `lazygit` on the worktree, running at open |
| `work` | 1 | `pi-local` interactive session, running at open |
| `work` | 2 | interactive zsh with the approval command prefilled, no `Enter` |

Only the approval pane waits for the owner. The other two start at open, so the owner sees the diff and the pi session with no key press. Pass `--no-kill`: the session belongs to the owner, so the script must keep the pane. The `pi` pane is the `--caller`, so the verification prompt lands in the session, not in a Hermes window.

## Owner access

Two layers gate the agent tmux server, and the skill needs both:

1. The directories. `logind` makes `/run/user/1000` mode `0700`, so `hermes` cannot traverse it. Two `a+` rules in `dendritic/hosts/Ramsay.nix` put `u:hermes:r-x` on `/run/user/1000` and on `tmux-1000`, and they stay non-recursive. A recursive `A+` rule also writes the entry onto the socket, and `r-x` there kills the write bit.
2. The socket. `agent` runs `tmux -S /run/user/1000/tmux-1000/default server-access -a hermes`. It grants `hermes` access and changes the mode from `srw-------` to `srwxrwx---`. Only the server owner or root can run it, so the agent runs it, never `hermes`. The agent must run it again after every server restart or switch, and `spawn-approval-session --grant hermes` runs it on every call.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `error connecting ... (Permission denied)` | No ACL on the runtime dir, or an `r-x` entry on the socket | Run `spawn-approval-session --grant hermes`, which runs the client as agent, or ask the agent to run `server-access` |
| Connect fails after a switch with the ACL in place | A recursive `A+` rule put `r-x` on the socket | Use the two `a+` rules, then run `server-access` |
| `error connecting ... (No such file or directory)` | No tmux server: `agent` never logged in | Ask the owner. Never start a server as `hermes` |
| `ambiguous target` on `server-access` | The `-S` socket was missing from the command | Always pass `-S <path>`, not `$TMUX` |
| `fatal: error opening '<worktree>/.git': Permission denied` | hermes created the worktree, so the files are `0600` and `agent` cannot read them | Owner runs `chown -R agent:users <worktree>` as root, then step 5 reruns |
| `sudo: a password is required` on `sudo -n -u agent ...` | hermes sudoers lists only `ramsay-deploy-switch`, so no other command runs without a password | agent runs the tmux commands. hermes never uses `sudo -u agent`. |

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
- Run step 1 as `hermes`. The tree comes out `hermes:hermes 0700`, and only root can undo it.
- Write the tmux recipe by hand for steps 5 and 6. `spawn-approval-session` owns the session layout.
- Run step 5 or 6 as `hermes`. The panes inherit the creator environment, so a hermes-built session has no agent `delta`, no agent `lazygit`, and no agent `pi-local`.
