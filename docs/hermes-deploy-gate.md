# Hermes deploy gate: autonomous `nh os switch` with hard approval

Hermes edits a private clone of NixConfig on Ramsay. It runs the switch itself. A code-level gate
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

Hermes runs as `hermes`, with no `wheel` membership and no `sudo` right. Add one rule.

```nix
security.sudo.extraRules = [
  {
    users = [ "hermes" ];
    commands = [
      # Fixed path, no arguments. sudoers cannot match a stored wrapper that
      # takes a caller-supplied argv.
      { command = "/run/current-system/sw/bin/ramsay-deploy-switch"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

`ramsay-deploy-switch` takes no arguments. It reads one fixed directory. That makes argument
injection impossible.

```sh
#!/usr/bin/env bash
set -euo pipefail
repo=/var/lib/hermes/NixConfig
exec 9>/run/lock/ramsay-deploy.lock
flock -n 9 || { echo "another deploy runs" >&2; exit 1; }
git -C "$repo" -c safe.directory="$repo" add -A
# A git-mode flake sees tracked files only. `add -A` makes a new file visible.
git -C "$repo" -c safe.directory="$repo" diff --cached --stat
exec nh os switch -e none "$repo#Ramsay"
```

Notes:

- `NH_OS_FLAKE=/root/NixConfig` exists on Ramsay. This wrapper passes the flake path instead, so
  the `hermes` clone is the deploy source.
- Root reads a `hermes`-owned repo. Pass `safe.directory` to `git`. Confirm that `nh` and `nix`
  accept the same path. Test this before you rely on it.
- The store path is read-only for `hermes`. The agent cannot edit the wrapper.
- The wrapper refuses to run when the clone is behind `origin/main`. A stale clone would roll the
  machine back. `ramsay-deploy-sync` fetches and rebases first.
- The wrapper commits the staged tree before the switch. Nix git mode then sees every file, and
  the change has a commit id to review.

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

## Layer 2: the agent gate

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

`ramsay-gate` reads JSON on stdin and writes JSON on stdout. The `approve` action escalates the
call to the same human gate that handles dangerous shell patterns.

```sh
#!/usr/bin/env bash
set -uo pipefail
payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.code // ""')
case "$cmd" in
  *ramsay-deploy-switch*)
    stat=$(git -C /var/lib/hermes/NixConfig diff --stat | tail -1)
    printf '{"action":"approve","message":"Deploy NixConfig: %s","rule_key":"ramsay-deploy"}\n' "$stat"
    ;;
  *) printf '{}\n' ;;
esac
```

Why this is a hard gate, per source:

- `hermes_cli/plugins.py::_resolve_block_from_details` runs the gate for an `approve` directive. A
  deny, a timeout or a gate error returns a block. The tool never runs.
- `tools/approval.py::request_tool_approval` sets `fail_closed_when_no_human`. A non-interactive
  session with no approval bridge blocks at once.
- `tools/approval_context.py` marks `api_server` as an unattended platform. It keeps an approval
  bridge only when the running turn registered a notifier. `/v1/runs` and streaming chat
  completions do register one. A plain webhook does not.

Set the approval modes explicitly:

```nix
approvals = {
  mode = "manual";            # "smart" lets a guardian model decide. "manual" asks every time.
  timeout = 300;              # A phone answer must fit in this window.
  unattended_mode = "deny";   # Unattended sessions get a block, not a card nobody sees.
  cron_mode = "deny";
  single_query_mode = "deny";
};
```

## Layer 3: the diff review

The approve card holds a description and a command. It holds no patch. No client renders a diff
inside an approval card.

### hermes-webui

The web UI has the richest surface. Use it for a full review.

- `api/route_approvals.py` serves the approval cards.
- The PWA manifest sets `display: standalone`. The Android home-screen app is this web UI.
- The tree has an inline diff viewer, an SSE approval stream and queue tests.

### Hermes Android client

`rusty4444/hermes-android` (Dart) reads `gateway_approval_dialog.dart`. The card shows
`request.description` and `request.command`, in monospace. The model `gateway_approval.dart`
parses no diff field. There is no diff widget in `lib/`.

The chat transcript is the review surface. It renders fenced code blocks with a copy button and a
wrap toggle, and long lines scroll sideways. Links open in the browser.

So the recipe posts the diff as a chat message first:

1. Sync. `ramsay-deploy-sync` fetches `origin/main` and rebases.
2. Run `ramsay-deploy-diff`. It prints `git diff HEAD` and the untracked file list.
3. Post the output in a `diff` fence. Add the web UI URL of the same commit.
4. Call `ramsay-deploy-switch`. The approve card appears with the diffstat.
5. Approve on the phone or in the web UI. A deny, or no answer, stops the switch.

### Optional: ntfy push

`AhmetArif0/hermes-ntfy-approval` sends the card to a phone as a push message. It has the buttons
Approve once, Approve for session and Deny. It needs `NTFY_APPROVAL_TOPIC` and, for a private
server, `NTFY_APPROVAL_TOKEN`. Add it only if the app is often closed.

## What defeats the gate

| Action | Result |
|---|---|
| `approvals.mode: off` | `tools/approval.py` returns approved before the gate. No prompt |
| `/yolo` or `HERMES_YOLO_MODE=true` | Same bypass, same line |
| `approvals.mode: smart` | A guardian model answers instead of the owner |
| Edit of `~/.hermes/config.yaml` | Nix merge replaces the Nix keys on the next switch |
| `HERMES_MANAGED=true` plus `.managed` | Shell edits of Nix-owned keys are refused |
| `security.approval.transport` set to a broken plugin | Transport error denies, unless the fallback is `builtin` |

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
| `dendritic/packages/ramsay-deploy.nix` | `ramsay-deploy-sync`, `ramsay-deploy-diff`, `ramsay-gate`, `ramsay-deploy-switch` |
| `dendritic/overlays.nix` | `pkgs.ramsayDeploy`, in `common-overlays` |
| `dendritic/nixos-modules/hermes.nix` | approvals, hooks, deny globs, `extraPackages`, sudo rule, clone unit |
| `dendritic/nixos-modules/hermes-skills/deploy/SKILL.md` | the five-step recipe for the agent |

One manual step remains: deploy with `nh os switch`. The agent must not build this change itself.

## Verification

```sh
# The wrapper is the only sudo path for hermes.
sudo -l -U hermes
# The hook blocks when it fails, and escalates when it matches.
hermes hooks list
hermes hooks test pre_tool_call --tool terminal --input '{"command":"ramsay-deploy-switch"}'
# The clone is a git-mode flake that evaluates.
systemctl status hermes-nixconfig
sudo -u hermes git -C /var/lib/hermes/NixConfig status --short
# A raw root route is refused before a prompt.
# Ask Hermes to run: sudo nh os switch → expect the deny glob, not a card.
```
