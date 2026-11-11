# One command that makes a NixConfig worktree for a branch, as agent.
#
# Step 1 of the nixconfig-worktree flow needs `wt`, and `wt` exists only in the
# agent profile at /etc/profiles/per-user/agent/bin. `/home/agent` is 0750
# agent:users, so hermes holds r-x there and cannot create a directory. A
# worktree hermes makes alone comes out hermes:hermes 0700, and only root can
# undo that. Before this command, hermes edited /home/agent/NixConfig directly,
# because that checkout is group-writable and its parent is not.
#
# The script copies the root pattern from spawn-approval-session. A root
# invocation re-executes itself through an agent login shell, so `wt` and the
# agent git config come from agent. Any other account gets an error instead of a
# worktree.
#
#   sudo -n /run/current-system/sw/bin/create-worktree bump-pi-1.2.1
#
# The worktree path goes to stdout, so the caller needs no `wt list` query. The
# command skips submodules unless you pass `--submodules`. That update clones
# every submodule from its URL and often leaves the worktree dirty.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.createWorktree = pkgs.writeShellApplication {
        name = "create-worktree";
        runtimeInputs = [
          inputs.worktrunk.packages.${pkgs.stdenv.hostPlatform.system}.worktrunk
          pkgs.coreutils
          pkgs.git
          pkgs.jq
        ];
        text = /* bash */ ''
          set -euo pipefail

          # shellcheck disable=SC2016  # The usage lines show variable names, so
          # single quotes are correct there.
          usage() {
            printf '%s\n' \
              'usage: create-worktree <branch> [options]' \
              '  --repo <path>     source checkout (default: $HOME/NixConfig)' \
              '  --submodules    run git submodule update --init in the new worktree' >&2
            exit 64
          }

          fail() {
            printf 'create-worktree: %s\n' "$1" >&2
            exit 1
          }

          # The agent account owns the checkout, so only agent may create a worktree.
          # A root invocation, the sudoers path, reruns itself through an agent login
          # shell, so agent owns every file the command writes.
          run_as="''${RUN_AS:-agent}"
          if [ "$(id -un)" != "$run_as" ]; then
            if [ "$(id -u)" -ne 0 ]; then
              printf 'create-worktree: only %s may create a worktree here. Run the command through sudo.\n' "$run_as" >&2
              exit 1
            fi
            args="$(printf '%q ' "$@")"
            exec runuser -l "$run_as" -c "exec $0 $args"
          fi

          branch=""
          repo=""
          submodules=0

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --repo) [ "$#" -ge 2 ] || usage; repo="$2"; shift 2 ;;
              --submodules) submodules=1; shift ;;
              -h|--help) usage ;;
              *)
                [ -z "$branch" ] || usage
                branch="$1"
                shift
                ;;
            esac
          done

          [ -n "$branch" ] || usage
          [ -n "$repo" ] || repo="$HOME/NixConfig"
          [ -e "$repo/.git" ] || fail "$repo is not a git checkout"

          # An existing branch needs no --create, because `wt switch <branch>` makes
          # the worktree for a branch that already exists.
          switch=(wt -C "$repo" switch --no-cd)
          if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
            :
          else
            switch+=(--create)
          fi

          # wt writes progress chatter, so keep it off stdout. Stdout carries the path.
          if ! out="$("''${switch[@]}" 2>&1)"; then
            printf '%s\n' "$out" >&2
            fail "''${switch[*]} failed"
          fi
          printf '%s\n' "$out" >&2

          path="$(wt -C "$repo" list --format json |
            jq -r --arg b "$branch" '[.[] | select(.branch == $b) | .path][0] // ""')"
          [ -n "$path" ] || fail "no worktree for branch $branch"

          if [ "$submodules" -eq 1 ]; then
            git -C "$path" submodule update --init
          fi

          printf '%s\n' "$path"
        '';
      };
    };
}
