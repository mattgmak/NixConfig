# The autonomous deploy path for the hermes user. Hermes edits
# /var/lib/hermes/NixConfig and asks to switch. The scripts split the job:
#
#   ramsay-deploy-sync      unprivileged. Fetches origin/main and rebases onto it.
#   ramsay-deploy-diff      unprivileged. Prints the review diff.
#   ramsay-deploy-tree      unprivileged. Prints the tree hash of the pending change.
#   ramsay-gate             unprivileged. The pre_tool_call hook. Blocks the switch
#                           unless a live approval token exists.
#   ramsay-deploy-approve   root, with a password. Shows the diff, then writes the
#                           token that unlocks one switch for 300 seconds.
#   ramsay-deploy-switch    root, through one no-argument sudoers rule. Checks the
#                           token and the tree, commits the clone, then switches.
#
# The gate does not ask Hermes for permission. Hermes drops the `approve`
# directive in the exec worker, so the gate returns `block` and reads a token
# that only a root-owned file can supply. The hermes user can read that file and
# cannot write it. See docs/hermes-deploy-gate.md.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      repo = "/var/lib/hermes/NixConfig";
      # Root-owned, world-readable: the gate reads it, and no agent writes it.
      approvalDir = "/var/lib/ramsay-deploy";
      approvalFile = "${approvalDir}/approval";
      approvalSeconds = 300;
      gitCommon = "-c safe.directory=${repo}";

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
            # The mirror carries main-repo objects only. Materialize the submodule
            # commits the new HEAD records, or the switch builds a mixed tree.
            git -C "$repo" submodule update --init --recursive --quiet
            echo "submodules at their recorded commits"
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
          (script "ramsay-deploy-tree" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.git pkgs.coreutils ]}
            repo=''${1:-${repo}}
            if [ ! -d "$repo/.git" ]; then
              echo "no clone at $repo" >&2
              exit 1
            fi
            # One hash over the exact bytes of the pending change. A commit does
            # not change it, and one edited file does.
            git -C "$repo" add -A
            git -C "$repo" write-tree
          '')
          (script "ramsay-gate" ''
            #!${pkgs.runtimeShell}
            set -uo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.jq pkgs.coreutils pkgs.gnused ]}
            token=${approvalFile}
            payload=$(cat 2>/dev/null || true)
            cmd=$(printf '%s' "$payload" | jq -r '(.tool_input.command // .tool_input.code // .args.command // .args.code // "") | tostring' 2>/dev/null || true)
            # A payload with no readable command still gets matched on its raw text. A block on a
            # harmless command costs one retry. A missed gate costs the machine.
            [ -n "$cmd" ] || cmd=$payload
            # Record every call. A silent gate hides its own failure.
            { printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              "$(printf '%s' "$payload" | jq -r '.tool_name // "?"' 2>/dev/null || true)" \
              "$(printf '%s' "$cmd" | head -c 200 | tr '\n' ' ')" >> /var/lib/hermes/ramsay-gate.log; } \
              2>/dev/null || true
            case "$cmd" in
              *ramsay-deploy-switch*)
                now=$(date +%s)
                expires=$(sed -n 's/^expires=//p' "$token" 2>/dev/null | head -1)
                if [ -n "$expires" ] && [ "$expires" -ge "$now" ] 2>/dev/null; then
                  printf '{}\n'
                  exit 0
                fi
                jq -nc --arg m "Deploy blocked: no approval token. Ask the owner to run sudo /run/current-system/sw/bin/ramsay-deploy-approve, then retry within ${toString approvalSeconds} seconds." \
                  '{action: "block", message: $m}'
                ;;
              *) printf '{}\n' ;;
            esac
          '')
          (script "ramsay-deploy-approve" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.gnused ]}
            repo=${repo}
            token=${approvalFile}
            if [ "$(id -u)" -ne 0 ]; then
              echo "run me with sudo: sudo /run/current-system/sw/bin/ramsay-deploy-approve" >&2
              exit 1
            fi
            if [ ! -d "$repo/.git" ]; then
              echo "no clone at $repo" >&2
              exit 1
            fi
            git -C "$repo" ${gitCommon} fetch --quiet origin main || true
            echo "== diffstat against origin/main =="
            git -C "$repo" ${gitCommon} --no-pager diff --stat origin/main
            echo
            echo "== diff =="
            git -C "$repo" ${gitCommon} --no-pager diff origin/main | head -500
            echo
            echo "== untracked =="
            git -C "$repo" ${gitCommon} ls-files --others --exclude-standard
            git -C "$repo" ${gitCommon} add -A
            tree=$(git -C "$repo" ${gitCommon} write-tree)
            now=$(date +%s)
            mkdir -p ${approvalDir}
            chmod 0755 ${approvalDir}
            printf 'tree=%s\napproved=%s\nexpires=%s\n' \
              "$tree" "$now" "$((now + ${toString approvalSeconds}))" > "$token"
            chmod 0644 "$token"
            # Root git leaves root-owned objects and an index. Give the clone back.
            chown -R "$(stat -c '%U:%G' "$repo")" "$repo/.git"
            echo
            echo "approved tree $tree for ${toString approvalSeconds} seconds"
            echo "next: sudo /run/current-system/sw/bin/ramsay-deploy-switch"
          '')
          (script "ramsay-deploy-switch" ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [
              pkgs.nh
              pkgs.git
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
              pkgs.util-linux
            ]}:/run/current-system/sw/bin
            repo=${repo}
            token=${approvalFile}
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
              # A root push adds root-owned objects. Keep the mirror readable.
              chgrp -R "$(stat -c '%G' "$repo")" "$mirror"
              chmod -R g+rX "$mirror"
            fi
            # A revert of a newer origin/main is a silent rollback. Refuse it.
            # Read the mirror ref directly: a fetch here writes root-owned objects
            # into the hermes clone and breaks the next sync.
            mirror_head=$(git -C "$mirror" rev-parse --verify -q refs/heads/main || true)
            if [ -n "$mirror_head" ] && ! git -C "$repo" ${gitCommon} \
              merge-base --is-ancestor "$mirror_head" HEAD; then
              echo "clone is behind origin/main: run ramsay-deploy-sync first" >&2
              exit 1
            fi
            # A git-mode flake sees tracked files only, so stage first.
            git -C "$repo" ${gitCommon} add -A
            # A stale submodule checkout builds a tree that no commit describes.
            if git -C "$repo" ${gitCommon} submodule status | grep -q '^[+-]'; then
              echo "clone has unmaterialized submodules: run ramsay-deploy-sync first" >&2
              exit 1
            fi
            # The owner answers through this file, and no agent can write it.
            if [ ! -r "$token" ]; then
              echo "no approval token: ask the owner to run sudo /run/current-system/sw/bin/ramsay-deploy-approve" >&2
              exit 1
            fi
            want=$(sed -n 's/^tree=//p' "$token" | head -1)
            expires=$(sed -n 's/^expires=//p' "$token" | head -1)
            now=$(date +%s)
            if [ -z "$want" ] || [ -z "$expires" ]; then
              echo "approval token is malformed: ask the owner to approve again" >&2
              exit 1
            fi
            if [ "$expires" -lt "$now" ]; then
              rm -f "$token"
              echo "approval expired: ask the owner to approve again" >&2
              exit 1
            fi
            have=$(git -C "$repo" ${gitCommon} write-tree)
            if [ "$have" != "$want" ]; then
              echo "tree changed since approval: ask the owner to approve the new diff" >&2
              exit 1
            fi
            # One approval, one switch.
            rm -f "$token"
            if ! git -C "$repo" ${gitCommon} diff --cached --quiet; then
              git -C "$repo" ${gitCommon} \
                diff --cached --stat | tee -a "$log"
              git -C "$repo" ${gitCommon} \
                -c user.name=hermes -c user.email=hermes@ramsay \
                commit -q -m "Hermes deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            fi
            rev=$(git -C "$repo" rev-parse --short HEAD)
            # Root git leaves root-owned files behind. Give the clone back to its owner.
            chown -R "$(stat -c '%U:%G' "$repo")" "$repo/.git"
            echo "deploy $rev" | tee -a "$log"
            exec nh os switch -e none "$repo#Ramsay"
          '')
        ];
      };
    };
}
