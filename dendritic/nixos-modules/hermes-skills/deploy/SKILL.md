---
name: deploy
description: >
  Deploy NixConfig to Ramsay. Use when a change in /var/lib/hermes/NixConfig
  must reach the running system. The owner approves every switch with a root
  command. Never route around the wrapper.
---

# deploy (NixConfig to Ramsay)

Hermes owns the change. The owner owns the switch. The gate blocks the switch until the owner
writes an approval token with `ramsay-deploy-approve`.

## Order

Run the steps in this order. Step 3 and step 5 may need several minutes between them.

1. Sync the clone. `ramsay-deploy-sync` commits the working tree, rebases, and updates submodules.
2. Show the diff. `ramsay-deploy-diff` — put the output in the reply, in a ```` ```diff ```` fence.
3. Ask for the switch. `sudo /run/current-system/sw/bin/ramsay-deploy-switch`
4. The gate blocks, and it says so. Tell the owner this exact line:

   ```
   sudo /run/current-system/sw/bin/ramsay-deploy-approve
   ```

5. Retry the switch within 300 seconds. A later retry needs a new approval.

## Commands

| Command | Root | Job |
|---|---|---|
| `ramsay-deploy-sync` | no | Commit the working tree, fetch, rebase, then `git submodule update` |
| `ramsay-deploy-diff` | no | `git diff origin/main` plus the untracked file list |
| `ramsay-deploy-tree` | no | Tree hash of the pending change |
| `sudo /run/current-system/sw/bin/ramsay-deploy-switch` | yes | Check the token and the tree, commit, then `nh os switch -e none .#Ramsay` |
| `sudo /run/current-system/sw/bin/ramsay-deploy-approve` | yes, with a password | Show the diff, then write a 300 second token. The owner runs this one |

The wrapper takes no arguments. It always reads `/var/lib/hermes/NixConfig`.

## Use the absolute path for sudo

The sudoers rule names `/run/current-system/sw/bin/ramsay-deploy-switch` and nothing else. A bare
`sudo ramsay-deploy-switch` resolves through your PATH to the store copy. The rule then misses, and
sudo asks for a password. This session cannot answer that prompt. Write the full path.

## Rules of the token

- Hermes never writes the token. It lives in `/var/lib/ramsay-deploy`, which root owns.
- The token names the tree hash.
- If you edit a file after the approval, the switch refuses. Sync, ask for a new approval, then retry.
- One approval allows one switch.
- Do not ask the owner to approve twice for the same diff.

## Never

- `sudo nh os switch`, `nixos-rebuild`, `sudo -i`, `sudo -s`, `sudo su` — a deny glob blocks each
  one, so they cannot work.
- `sudo /run/current-system/sw/bin/ramsay-deploy-approve`. Your sudo rule does not allow it.
- An edit of `~/.hermes/config.yaml` for `approvals` or `hooks`. Nix owns those keys.
- A switch from `/root/NixConfig` or another worktree. The wrapper is the only root path.

## Failures

| Symptom | Cause | Fix |
|---|---|---|
| `sudo` asks for a password | The command path missed the sudoers rule | Use `/run/current-system/sw/bin/ramsay-deploy-switch` |
| `Deploy blocked: no approval token` | No live token | Ask the owner for `ramsay-deploy-approve`, then retry |
| `approval expired` | More than 300 s since the approval | Ask the owner to approve again |
| `tree changed since approval` | The working tree changed after the approval | Sync, show the diff, ask for a new approval |
| `clone is behind origin/main` | The mirror moved ahead of the clone | Run `ramsay-deploy-sync`, then retry |
| `clone has unmaterialized submodules` | Old submodule checkouts | Run `ramsay-deploy-sync`, then retry |
| `another deploy runs` | A switch holds the lock | Wait. Check `systemctl status hermes-agent` |
| `no clone at /var/lib/hermes/NixConfig` | The clone unit failed | Check `systemctl status hermes-nixconfig` |
