# Hermes deploy gate: autonomous `nh os switch` with hard approval

Hermes works in the agent checkout of NixConfig on Ramsay. It runs the switch itself. A code-level gate
stops the switch until the owner approves it on a phone or in the web UI.

Checked against `hermes-agent` pin `ef75bc708867e3884cb40a91363be6dc6fddc034` and
`hermes-webui` `v0.52.544`.

## Design rule

The gate has three layers. Each layer must pass.

| Layer | Mechanism | Fails closed | Lives in |
|---|---|---|---|
| OS | `sudo` allows one fixed-argv wrapper only | yes | `security.sudo`, store script |
| Agent | `pre_tool_call` shell hook escalates to the human gate | yes | `hooks:` in `config.yaml` |
| Review | Diff posted in chat before the request | no, informational | Hermes skill and chat UI |

Do not use `approvals.deny` as the gate. A deny rule blocks the command for all time, and no
approval can release it.

## Layer 1: the OS path

Hermes runs as `agent`. The account holds one `PASSWD` rule for `ALL` and two
`NOPASSWD` rules, one for `ramsay-deploy-approve` and one for
`ramsay-deploy-switch`. The approval pane uses the second pair, so a phone
approval needs no typed secret.

```nix
security.sudo.extraRules = [
  {
    users = [ "agent" ];
    commands = [
      { command = "ALL"; options = [ "PASSWD" ]; }
    ];
  }
  # Keep the NOPASSWD specs in a rule of their own, after the ALL rule.
  # sudo sorts specs by option, so a NOPASSWD listed before PASSWD loses.
  {
    users = [ "agent" ];
    commands = [
      { command = "/run/current-system/sw/bin/ramsay-deploy-approve"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/ramsay-deploy-switch"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

The merge costs one property. The `hermes` account once lacked the approve rule,
so it could not approve its own change. The `agent` account holds the rule, so
the `pre_tool_call` hook and the skill now carry that rule, not sudoers.

`ramsay-deploy-switch` takes no arguments. It reads one fixed directory. That makes argument
injection impossible.

```sh
#!/usr/bin/env bash
set -euo pipefail
repo=/home/agent/NixConfig
exec 9>/run/lock/ramsay-deploy.lock
flock -n 9 || { echo "another deploy runs" >&2; exit 1; }
git -C "$repo" -c safe.directory="$repo" add -A
# A git-mode flake sees tracked files only. `add -A` makes a new file visible.
git -C "$repo" -c safe.directory="$repo" diff --cached --stat
exec nh os switch -e none "$repo#Ramsay"
```

Notes:

- `NH_OS_FLAKE=/root/NixConfig` exists on Ramsay. This wrapper passes the flake path instead, so
  the agent checkout is the deploy source.
- Root reads an `agent`-owned repo. Pass `safe.directory` to `git`. Confirm that `nh` and `nix`
  accept the same path. Test this before you rely on it.
- The store path is read-only for `agent`. The agent cannot edit the wrapper.
- `ramsay-deploy-approve` checks the repo's own `refs/remotes/origin/main`, then refuses when
  HEAD does not match it. A push inside the switch moves `origin/main` past a checkout that
  just synced, and the switch then refuses its own push.
- The checkout takes GitHub as its origin. `/root/NixConfig` and `/var/lib/hermes` are links,
  not copies.
- The wrapper checks the token before it touches git. A call without one writes nothing: no
  staging, no root-owned index, no checkout change.
- The wrapper commits the staged tree before the switch. Nix git mode then sees every file, and
  the change has a commit id to review.
- A trap gives `.git` back to its owner on every exit path, including a refusal.

Hard-block the raw root paths, so the wrapper is the only route:

```nix
approvals.deny = [
  "*nh os switch*"
  "*nh os boot*"
  "*nixos-rebuild*"
  "*sudo -i*"
  "*sudo -s*"
  "*sudo su*"
];
```

## Layer 2: the token gate

`nh` and `nix` are absent from `DANGEROUS_PATTERNS` in `tools/approval_detection.py`. So a plain
`nh os switch` raises no prompt. Add one shell hook instead.

```nix
hooks_auto_accept = true;   # A gateway and a cron run cannot answer a TTY consent prompt.
hooks.pre_tool_call = [
  {
    matcher = "terminal|execute_code";
    command = "${pkgs.ramsayDeploy}/bin/ramsay-gate";
    timeout = 15;
    fail_closed = true;     # A crash, a timeout or bad JSON blocks the call.
  }
];
```

`ramsay-gate` reads JSON on stdin and writes JSON on stdout. It blocks the switch unless a live
approval token exists.

```sh
payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
case "$cmd" in
  *ramsay-deploy-switch*)
    now=$(date +%s)
    expires=$(sed -n 's/^expires=//p' /var/lib/ramsay-deploy/approval 2>/dev/null | head -1)
    if [ -n "$expires" ] && [ "$expires" -ge "$now" ] 2>/dev/null; then
      printf '{}\n'; exit 0
    fi
    printf '{"action":"block","message":"Deploy blocked: no approval token."}\n'
    ;;
  *) printf '{}\n' ;;
esac
```

Use `block`, not `approve`. I measured both with `scripts/hermes-gate-tmux-test.sh`. Hermes runs a
tool in a detached exec worker, and that worker honors `block` and drops `approve`. An `approve`
directive let the switch run with no human.

### The token

| Rule | Reason |
|---|---|
| `ramsay-deploy-approve` needs root and a password | Hermes holds no sudo rule for it, so it cannot approve itself |
| `/var/lib/ramsay-deploy/approval` is root-owned, 0644 | The gate reads it, and no agent writes it |
| The token names the tree hash of the pending change | The owner approves exact bytes |
| The token expires in 300 s | A stale approval cannot unlock a later deploy |
| The switch deletes the token before `nh` | One approval, one switch |
| The switch checks the token before any git write | A call without approval leaves the clone clean |
| The switch recomputes the tree hash after `git add -A` | An edit after approval refuses, and the owner approves again |

The tree hash comes from `git add -A` then `git write-tree`. A commit does not change it, and one
edited file does.

Set the approval modes explicitly as well. They guard every other dangerous pattern:

```nix
approvals = {
  mode = "manual";            # "smart" lets a guardian model decide. "manual" asks every time.
  timeout = 300;              # A phone answer must fit in this window.
  unattended_mode = "deny";   # Unattended sessions get a block, not a card nobody sees.
  cron_mode = "deny";
  single_query_mode = "deny";
};
```

## The diff review

`ramsay-deploy-approve` prints three things, then writes the token: the diffstat against
`origin/main`, the diff itself (first 500 lines), and the untracked file list. Read that output
before you approve.

For a phone review, ask Hermes for `ramsay-deploy-diff` first. It prints the same diff. Put the
output in a `diff` fence in the chat. The chat is the review surface now, because the token
replaces the card.

### The order

1. Hermes runs `ramsay-deploy-sync`. The clone commits, fetches, rebases, and updates submodules.
2. Hermes runs `ramsay-deploy-diff`, and posts the output in a `diff` fence.
3. Hermes calls `sudo /run/current-system/sw/bin/ramsay-deploy-switch`. The gate blocks it.
4. The owner reads the diff, then runs `sudo /run/current-system/sw/bin/ramsay-deploy-approve`.
5. Hermes retries the switch within 300 s. The wrapper checks the token and the tree, then switches.

A second switch needs a second approval.

## What defeats the gate

| Action | Result |
|---|---|
| `approvals.mode: off` | `tools/approval.py` returns approved before the gate. No prompt |
| `/yolo` or `HERMES_YOLO_MODE=true` | Same bypass, same line |
| `approvals.mode: smart` | A guardian model answers instead of the owner |
| Edit of `~/.hermes/config.yaml` | Nix merge replaces the Nix keys on the next switch |
| `HERMES_MANAGED=true` plus `.managed` | Shell edits of Nix-owned keys are refused |
| `security.approval.transport` set to a broken plugin | Transport error denies, unless the fallback is `builtin` |
| Chat opened before the hook reached `config.yaml` | The worker registers hooks from the session snapshot, so that chat has no gate. The token still holds |
| Detached exec worker (`HERMES_AGENT` plus `HERMES_GATEWAY_DETACHED`) | Hermes ignores `{"action":"approve"}` there, and the call runs. `{"action":"block"}` does stop it |

Two tests prove the last two rows. `scripts/hermes-gate-test.sh` spawns one turn on the local
model. `scripts/hermes-gate-tmux-test.sh` compares `block` against `approve` in a tmux pane.

So `approve` is not a gate. The wrapper must check a token that only a human answer writes.

Keep `mode = "manual"` under Nix control. That keeps the bypass keys out of the agent's reach
between switches.

Residual risk: an agent with write access to `~/.hermes` can change a non-Nix key and restart the
gateway. A `systemctl restart` of its own unit needs no root. Treat the OS layer as the real
guarantee. The Hermes layer is the convenience gate.

## Options that do not help here

| Candidate | Verdict |
|---|---|
| `ntfy-approval` | Useful phone push. Presentation only, no policy |
| `approval-ledger` | Audit record of each decision. Add after the gate works |
| `diff-review` | Analyses a diff for quality. It does not gate a deploy |
| `hermes-session-diff` | Desktop only, session file diffs |
| `external-app-tab` (webui extension) | Embeds a URL in a rail tab. No policy value |
| `project-folders` (webui extension) | Sidebar folders. No policy value |
| `container.enable` | Container sessions skip dangerous-command checks |

## Files

| File | Holds |
|---|---|
| `dendritic/packages/ramsay-deploy.nix` | `ramsay-deploy-sync`, `ramsay-deploy-diff`, `ramsay-deploy-tree`, `ramsay-gate`, `ramsay-deploy-approve`, `ramsay-deploy-switch` |
| `dendritic/overlays.nix` | `pkgs.ramsayDeploy`, in `common-overlays` |
| `dendritic/nixos-modules/hermes.nix` | approvals, hooks, deny globs, `extraPackages`, the `agent` user and group |
| `dendritic/nixos-modules/hermes-skills/deploy/SKILL.md` | the five-step recipe for the agent |
| `scripts/hermes-gate-test.sh` | one spawned Hermes turn, with the payload and the verdict |
| `scripts/hermes-gate-tmux-test.sh` | the `block` against `approve` comparison |

One manual step remains: deploy with `nh os switch`. The agent must not build this change itself.

## Verification

```sh
# The account runs the wrapper without a password prompt for approve and switch.
sudo -l -U agent
# The gate blocks the switch with no token, and it allows a benign call.
printf '%s' '{"tool_name":"terminal","tool_input":{"command":"sudo /run/current-system/sw/bin/ramsay-deploy-switch"}}' \
  | /run/current-system/sw/bin/ramsay-gate
# A fresh approval writes the token, and hermes can read it.
sudo /run/current-system/sw/bin/ramsay-deploy-approve
ls -l /var/lib/ramsay-deploy/approval
# The checkout is a git-mode flake that evaluates.
git -C /home/agent/NixConfig status --short
# A raw root route is refused before a prompt.
# Ask Hermes to run: sudo nh os switch → expect the deny glob, not a card.
```
