---
name: deploy
description: >
  Deploy NixConfig to Ramsay. Use when a change in /var/lib/hermes/NixConfig
  must reach the running system. The owner approves every switch from a phone
  or the web UI. Never route around the wrapper.
---

# deploy (NixConfig to Ramsay)

Hermes owns the change. The owner owns the switch. `ramsay-deploy-switch` stops at an approval
card, and the card waits for the owner.

## Order

Run the steps in this order. Do not skip step 2.

1. Sync the clone. `ramsay-deploy-sync` — this commits the working tree and updates the submodules.
2. Show the diff. `ramsay-deploy-diff` — put the output in the reply, in a ```` ```diff ```` fence.
   The owner reads it on the phone.
3. Ask for the switch. `sudo /run/current-system/sw/bin/ramsay-deploy-switch`
4. Report the result. The wrapper prints the commit and the switch output.

## Commands

| Command | Root | Job |
|---|---|---|
| `ramsay-deploy-sync` | no | Commit the working tree, fetch, rebase, then `git submodule update` |
| `ramsay-deploy-diff` | no | `git diff origin/main` plus the untracked file list |
| `sudo /run/current-system/sw/bin/ramsay-deploy-switch` | yes | Commit any new change, then `nh os switch -e none .#Ramsay` |

The wrapper takes no arguments. It always reads `/var/lib/hermes/NixConfig`.

## Use the absolute path for sudo

The sudoers rule names `/run/current-system/sw/bin/ramsay-deploy-switch` and nothing else. A bare
`sudo ramsay-deploy-switch` resolves through your PATH to the store copy, so the rule misses and
sudo asks for a password. This session cannot answer that prompt. Write the full path.

## What the approval card means

The card holds the diffstat. A deny, or no answer within 300 s, stops the switch. The command does
not run. Do not retry a denied switch.

## Never

- `sudo nh os switch`, `nixos-rebuild`, `sudo -i`, `sudo -s`, `sudo su` — a deny glob blocks each
  one. They cannot work.
- Edit `~/.hermes/config.yaml` to change `approvals` or `hooks`. Nix owns those keys.
- Switch from `/root/NixConfig` or another worktree. The wrapper is the only root path.

## Failures

| Symptom | Cause | Fix |
|---|---|---|
| `sudo` asks for a password | The command path missed the sudoers rule | Use `/run/current-system/sw/bin/ramsay-deploy-switch` |
| `clone is behind origin/main` | The mirror moved ahead of the clone | Run `ramsay-deploy-sync`, then retry |
| `clone has unmaterialized submodules` | Old submodule checkouts | Run `ramsay-deploy-sync`, then retry |
| `another deploy runs` | A switch holds the lock | Wait. Check `systemctl status hermes-agent` |
| `no clone at /var/lib/hermes/NixConfig` | The clone unit failed | Check `systemctl status hermes-nixconfig` |
| `BLOCKED: ... no interactive user` | The session has no approval bridge | Ask the owner to open the web UI or the app, then retry |
| Card never appears | The hook is off | Check `hermes hooks list` for `pre_tool_call` |
