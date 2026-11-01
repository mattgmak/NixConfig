# The autonomous deploy path for the hermes user. Hermes edits
# /var/lib/hermes/NixConfig and asks to switch. The scripts split the job:
#
#   ramsay-deploy-sync    unprivileged. Fetches origin/main and rebases onto it.
#   ramsay-deploy-diff    unprivileged. Prints the review diff.
#   ramsay-gate           unprivileged. The pre_tool_call hook. Escalates the
#                         switch to the human approval gate.
#   ramsay-deploy-switch  root, through one no-argument sudoers rule. Commits
#                         the clone and runs the switch.
#
# The gate is a hook, not a sudoers trick: a deny, a timeout or a broken hook
# blocks the call, so the switch cannot run without an answer. See
# docs/hermes-deploy-gate.md.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      repo = "/var/lib/hermes/NixConfig";

      # writeTextFile, not writeShellApplication: the scripts stay out of
      # shellcheck's way, and each one sets its own PATH because sudo resets it.
      script =
        name: text:
        pkgs.writeTextFile {
          inherit name text;
          executable = true;
          destination = "/bin/${name}";
          meta.description = "Ramsay deploy helper: ${name}";
        };
    in
    {
      packages.ramsayDeploy = pkgs.buildEnv {
        name = "ramsay-deploy";
        # buildEnv merges each bin/ directory. symlinkJoin would keep one.
        paths = [
          (script "ramsay-deploy-sync" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.git pkgs.coreutils ]}
            repo=${repo}
            # Commit first. A rebase over a dirty tree refuses to run.
            git -C "$repo" add -A
            if ! git -C "$repo" diff --cached --quiet; then
              git -C "$repo" -c user.name=hermes -c user.email=hermes@ramsay \
                commit -q -m "Hermes deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            fi
            # origin is the root-owned mirror, so this fetch stays local and cheap.
            git -C "$repo" fetch --quiet origin main
            if git -C "$repo" merge-base --is-ancestor origin/main HEAD; then
              echo "clone is current with origin/main"
            else
              git -C "$repo" -c user.name=hermes -c user.email=hermes@ramsay \
                rebase origin/main
            fi
          '')
          (script "ramsay-deploy-diff" ''
            #!${pkgs.runtimeShell}
            set -uo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.git pkgs.coreutils ]}
            repo=${repo}
            if [ ! -d "$repo/.git" ]; then
              echo "no clone at $repo" >&2
              exit 1
            fi
            git -C "$repo" fetch --quiet origin main || true
            # Compare to origin/main, not HEAD: the sync step commits first.
            git -C "$repo" --no-pager diff origin/main
            echo
            echo "untracked:"
            git -C "$repo" ls-files --others --exclude-standard
          '')
          (script "ramsay-gate" ''
            #!${pkgs.runtimeShell}
            set -uo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.jq pkgs.git pkgs.coreutils ]}
            payload=$(cat 2>/dev/null || true)
            cmd=$(printf '%s' "$payload" | jq -r '(.tool_input.command // .tool_input.code // "") | tostring' 2>/dev/null || true)
            case "$cmd" in
              *ramsay-deploy-switch*)
                stat=$(git -C ${repo} --no-pager diff --stat origin/main 2>/dev/null | tail -1)
                [ -n "$stat" ] || stat="no change"
                jq -nc --arg m "Deploy NixConfig to Ramsay. $stat" \
                  '{action: "approve", message: $m, rule_key: "ramsay-deploy"}'
                ;;
              *) printf '{}\n' ;;
            esac
          '')
          (script "ramsay-deploy-switch" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [
              pkgs.nh
              pkgs.git
              pkgs.coreutils
              pkgs.util-linux
            ]}:/run/current-system/sw/bin
            repo=${repo}
            log=/var/log/ramsay-deploy.log
            if [ ! -d "$repo/.git" ]; then
              echo "no clone at $repo" >&2
              exit 1
            fi
            exec 9>/run/lock/ramsay-deploy.lock
            flock -n 9 || { echo "another deploy runs" >&2; exit 1; }
            # Publish the tree that was last switched. Without this, a stale
            # origin/main lets the clone roll the machine back.
            src=/home/agent/NixConfig
            mirror=/var/lib/hermes/NixConfig.git
            if [ -d "$src/.git" ] && [ -d "$mirror" ]; then
              git -C "$src" -c safe.directory="$src" push --quiet --force \
                "$mirror" HEAD:refs/heads/main || true
            fi
            # A revert of a newer origin/main is a silent rollback. Refuse it.
            git -C "$repo" -c safe.directory="$repo" fetch --quiet origin main || true
            if ! git -C "$repo" -c safe.directory="$repo" \
              merge-base --is-ancestor origin/main HEAD; then
              echo "clone is behind origin/main: run ramsay-deploy-sync first" >&2
              exit 1
            fi
            # A git-mode flake sees tracked files only, so stage first.
            git -C "$repo" -c safe.directory="$repo" add -A
            if ! git -C "$repo" -c safe.directory="$repo" diff --cached --quiet; then
              git -C "$repo" -c safe.directory="$repo" \
                diff --cached --stat | tee -a "$log"
              git -C "$repo" -c safe.directory="$repo" \
                -c user.name=hermes -c user.email=hermes@ramsay \
                commit -q -m "Hermes deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            fi
            rev=$(git -C "$repo" rev-parse --short HEAD)
            echo "deploy $rev" | tee -a "$log"
            exec nh os switch -e none "$repo#Ramsay"
          '')
        ];
      };
    };
}
