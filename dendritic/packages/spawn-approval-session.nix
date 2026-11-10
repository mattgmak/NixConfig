# One command that opens the review session for a NixConfig branch.
#
# The session must belong to the agent tmux server, because tmux copies the
# environment of the creating process into every pane it makes. A hermes shell
# that runs tmux itself gets the hermes environment, so its panes lose pi-local,
# delta, and lazygit. Only agent ever creates a session. A root invocation
# re-executes itself through an agent login shell, so the environment comes from
# agent, and `new-session` passes PATH, HOME, USER, and ZDOTDIR explicitly. Any
# other account gets an error instead of a session.
#
#   sudo spawn-approval-session bump-pi-1.1.7 --grant hermes
#   sudo spawn-approval-session bump-pi-1.1.7 \
#     --worktree /home/agent/NixConfig.bump-pi-1.1.5 --force
#
# Hermes gets one NOPASSWD rule for this path, so the fixed argv needs no
# password. See dendritic/nixos-modules/hermes.nix and the skill
# dendritic/nixos-modules/hermes-skills/nixconfig-worktree/SKILL.md.
#
# The session is one window with three panes:
#
#   pi-local on the left, the session that wrote the change
#   lazygit on the worktree in the top-right
#   an interactive shell with the approve command prefilled in the bottom-right
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.spawnApprovalSession = pkgs.writeShellApplication {
        name = "spawn-approval-session";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.tmux
          pkgs.util-linux
        ];
        text = /* bash */ ''
          set -euo pipefail

          # shellcheck disable=SC2016  # The usage lines show variable names, so
          # single quotes are correct there.
          usage() {
            printf '%s\n' \
              'usage: spawn-approval-session <branch> [options]' \
              '  --worktree <path>  worktree to open (default: $HOME/NixConfig.<branch>)' \
              '  --session <name>   session name (default: NixConfig-<branch>)' \
              '  --grant <user>     give that user access to the tmux socket' \
              '  --force            kill an existing session before creating it' \
              '  --no-work          create only the review window' \
              '  --approve <cmd>    command to prefill in the approval pane' >&2
            exit 64
          }

          # The agent account owns the server, so only agent may create a session.
          # A root invocation, the sudoers path, reruns itself through an agent login
          # shell: the login shell sets agent's PATH, HOME, and USER, so nothing from
          # the sudo wrapper or the calling account survives. Any other account is
          # refused, because a session made by hermes belongs to hermes.
          run_as="''${SPAWN_RUN_AS:-agent}"
          if [ "$(id -un)" != "$run_as" ]; then
            if [ "$(id -u)" -ne 0 ]; then
              printf 'spawn-approval-session: only %s may create a session on the agent server. Run the command through sudo.\n' "$run_as" >&2
              exit 1
            fi
            args="$(printf '%q ' "$@")"
            exec runuser -l "$run_as" -c "exec $0 $args"
          fi

          branch=""
          worktree=""
          session=""
          grant=""
          approve=""
          force=0
          work=1

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --worktree) worktree="$2"; shift 2 ;;
              --session) session="$2"; shift 2 ;;
              --grant) grant="$2"; shift 2 ;;
              --approve) approve="$2"; shift 2 ;;
              --force) force=1; shift ;;
              --no-work) work=0; shift ;;
              -h|--help) usage ;;
              *)
                [ -z "$branch" ] || usage
                branch="$1"
                shift
                ;;
            esac
          done

          [ -n "$branch" ] || usage
          [ -n "$worktree" ] || worktree="$HOME/NixConfig.$branch"
          [ -n "$session" ] || session="NixConfig-$branch"

          if [ ! -d "$worktree" ]; then
            printf 'spawn-approval-session: no directory at %s. Create the worktree as agent with wt switch --create %s.\n' \
              "$worktree" "$branch" >&2
            exit 1
          fi

          # A hermes-created worktree keeps .git at mode 0600 hermes:hermes, which
          # agent cannot open. Catch it here instead of in a dead pane.
          if [ -f "$worktree/.git" ] && [ ! -r "$worktree/.git" ]; then
            printf 'spawn-approval-session: %s/.git is not readable, so the tree belongs to another user. Only root can chown it to agent:users.\n' \
              "$worktree" >&2
            exit 1
          fi

          socket="''${SPAWN_TMUX_SOCKET:-}"
          if [ -z "$socket" ]; then
            socket="/run/user/$(id -u)/tmux-$(id -u)/default"
          fi

          if [ ! -S "$socket" ]; then
            printf 'spawn-approval-session: no tmux socket at %s. Start the agent tmux server first.\n' "$socket" >&2
            exit 1
          fi

          tmux() {
            command tmux -S "$socket" "$@"
          }

          # A session name with dots needs the trailing-colon form, because tmux
          # reads a bare dot as the window and pane separator.
          if tmux has-session -t "$session:" 2>/dev/null; then
            if [ "$force" -eq 1 ]; then
              tmux kill-session -t "$session:"
            else
              printf 'spawn-approval-session: session %s already exists. Pass --force to replace it.\n' "$session" >&2
              exit 1
            fi
          fi

          if [ -n "$grant" ]; then
            # tmux exits 1 when the user already has socket access, so ignore the result.
            tmux server-access -a "$grant" || true
          fi

          # tmux keeps an environment table per session, and `new-session -e` fills
          # it. A pane process copies the server's environment instead, so the flags
          # alone leave the wrong PATH in every pane. Put `env` in front of each pane
          # command: that sets the environment of the process the pane runs.
          # The caller's PATH is wrong here, because a sudo or hermes call carries its
          # own profile dirs, so a pane finds the wrong pi-local. Name the login PATH
          # of the account that owns the server.
          user="$(id -un)"
          shell="''${SPAWN_SHELL:-/run/current-system/sw/bin/zsh}"
          session_path="''${SPAWN_PATH:-/run/wrappers/bin:$HOME/.nix-profile/bin:/nix/profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/$user/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin}"
          envstr="PATH=$session_path HOME=$HOME USER=$user"
          if [ -d "$HOME/.config/zsh" ]; then
            envstr="$envstr ZDOTDIR=$HOME/.config/zsh"
          fi

          review="env $envstr $shell -i -c 'l; exec $shell -i'"
          workcmd="env $envstr $shell -i -c 'pi-local; exec $shell -i'"
          shellcmd="env $envstr $shell -i"

          # One window holds every pane, so the owner sees the pi session, the
          # diff, and the approval command together. The layout is fixed: pi on
          # the left, lazygit top-right, the approval shell bottom-right.
          if [ "$work" -eq 1 ]; then
            pi_pane="$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$worktree" -n work "$workcmd")"
            lg_pane="$(tmux split-window -h -P -F '#{pane_id}' -t "$pi_pane" -c "$worktree" "$review")"
            ap_pane="$(tmux split-window -v -P -F '#{pane_id}' -t "$lg_pane" -c "$worktree" "$shellcmd")"
            if [ -z "$approve" ]; then
              approve="cd $worktree && scripts/approve-and-deploy.sh $branch --caller $pi_pane --no-kill"
            fi
            # The owner presses Enter, so the command goes in without a newline.
            tmux send-keys -t "$ap_pane" -l "$approve"
          else
            tmux new-session -d -s "$session" -c "$worktree" -n review "$review"
          fi

          tmux list-panes -s -t "$session:" -F '#{window_name} #{pane_id} #{pane_start_command}'
        '';
      };
    };
}
