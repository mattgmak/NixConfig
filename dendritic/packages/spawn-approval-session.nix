# One command that opens the review session for a NixConfig branch.
#
# The session must belong to the agent tmux server, because tmux copies the
# environment of the creating process into every pane it makes. A hermes shell
# that runs tmux itself gets the hermes environment, so its panes lose pi-local,
# delta, and lazygit. This script names the environment instead of inheriting it:
# a root invocation re-executes itself as agent with runuser, and `new-session`
# passes PATH, HOME, USER, and ZDOTDIR explicitly.
#
#   sudo spawn-approval-session bump-pi-1.1.7 --grant hermes
#   sudo spawn-approval-session bump-pi-1.1.7 \
#     --worktree /home/agent/NixConfig.bump-pi-1.1.5 --force
#
# Hermes gets one NOPASSWD rule for this path, so the fixed argv needs no
# password. See dendritic/nixos-modules/hermes.nix and the skill
# dendritic/nixos-modules/hermes-skills/nixconfig-worktree/SKILL.md.
#
# The session holds three panes:
#
#   review   lazygit on the worktree
#   work     pi-local, the session that wrote the change
#   work     interactive shell with the approve command prefilled, no Enter
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

          # The agent account owns the server the panes must run in. A root
          # invocation, the sudoers path, hands the work to that account and reruns
          # itself, so every tmux call comes from the account the server belongs to.
          run_as="''${SPAWN_RUN_AS:-agent}"
          if [ "$(id -u)" -eq 0 ] && [ "$(id -un)" != "$run_as" ]; then
            exec runuser -u "$run_as" -- "$0" "$@"
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

          # tmux stores this environment in the session record, and every later
          # window and pane inherits it, so only new-session needs the flags.
          # The caller's PATH is wrong here: a sudo or hermes call carries its own
          # profile dirs, so a pane finds the wrong pi-local. Name the login PATH of
          # the account that owns the server instead.
          user="$(id -un)"
          session_path="''${SPAWN_PATH:-/run/wrappers/bin:$HOME/.nix-profile/bin:/nix/profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/$user/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin}"
          envargs=(-e "PATH=$session_path" -e "HOME=$HOME" -e "USER=$user")
          if [ -d "$HOME/.config/zsh" ]; then
            envargs+=(-e "ZDOTDIR=$HOME/.config/zsh")
          fi

          shell="''${SPAWN_SHELL:-/run/current-system/sw/bin/zsh}"
          review="$shell -i -c 'lazygit; exec $shell -i'"
          workcmd="$shell -i -c 'pi-local; exec $shell -i'"

          tmux new-session -d -s "$session" -c "$worktree" -n review "''${envargs[@]}" "$review"

          if [ "$work" -eq 1 ]; then
            pi_pane="$(tmux new-window -d -P -F '#{pane_id}' -t "$session:" -n work -c "$worktree" "$workcmd")"
            if [ -z "$approve" ]; then
              approve="cd $worktree && scripts/approve-and-deploy.sh $branch --caller $pi_pane --no-kill"
            fi
            ap_pane="$(tmux split-window -h -P -F '#{pane_id}' -t "$session:work" -c "$worktree" "$shell -i")"
            # The owner presses Enter, so the command goes in without a newline.
            tmux send-keys -t "$ap_pane" -l "$approve"
          fi

          tmux list-panes -s -t "$session:" -F '#{window_name} #{pane_id} #{pane_start_command}'
        '';
      };
    };
}
