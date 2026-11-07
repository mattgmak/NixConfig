# One command that reaches the clipboard and the browser of the machine you
# actually sit at.
#
# A headless host has no opener and no live clipboard provider, so `open` and
# `copy` have to run on the ssh client instead. Every client ssh host block
# publishes its name with SetEnv LC_PI_CLIP, and the zsh login hook links
# ~/.pi-clip/by-tty/<tty>.sock to that client's socket. The link names the
# machine for any shell, including tmux panes that never see SSH_TTY.
#
#   tmux-bridge open <target>   open a file or URL
#   tmux-bridge copy            read a selection from stdin
#   tmux-bridge client          print the resolved client, for debugging
#
# Precedence: PI_OPEN / PI_COPY / PI_CLIENT override, then the by-tty link,
# then this host's own open, xdg-open, pbcopy, wl-copy, xsel or xclip.
#
# A plain ssh login shell on a Linux client carries no display, so its entries
# name the Wayland socket of the running compositor. Without it, the
# `xdg-open` there exits 1 and fzf-tmux-url reports the failure.
#
# TODO: fold the table into the pi-clip protocol once it gains open and write
# verbs. The socket is read-only today, so ssh carries these two calls.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.lib) concatStringsSep mapAttrsToList;

      # Options for every ssh call. ControlPath spells out $HOME: a tilde never
      # expands after `=`, so the old `ControlPath=~/.ssh/...` pointed at a path
      # under the current directory and no call ever reused a connection.
      sshOpts = "-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o \"ControlPath=$HOME/.ssh/cm-%r@%h:%p\" -o ControlPersist=yes";

      # The Wayland socket of a Linux client as one `env` argument. The quotes
      # and the backslashes keep the substitution away from the local shell, so
      # only the client shell runs it.
      waylandEnv = "\"WAYLAND_DISPLAY=\\$(cd /run/user/\\$UID 2>/dev/null && ls -1t | grep -m1 ^wayland-)\"";

      # name -> the ssh target plus the opener and the copier on that machine.
      # Entries are complete argument lists, so a value with spaces needs its own
      # quotes. macmini is verified live; desky and envy take their user from
      # dendritic/constants.nix. The wl-copy entries quote their redirect so it
      # survives the join into one remote command line: wl-copy forks a child that
      # holds the ssh channel open, so ssh waits forever unless the remote output
      # is not a pipe.
      clients = {
        macmini = {
          target = "mattgmak@macmini.dab-octatonic.ts.net";
          open = "/usr/bin/open";
          copy = "/usr/bin/pbcopy";
        };
        desky = {
          target = "goofy@goofydesky.dab-octatonic.ts.net";
          open = "env ${waylandEnv} xdg-open";
          copy = "env ${waylandEnv} wl-copy '>' '/dev/null' '2>&1'";
        };
        envy = {
          target = "goofy@goofyenvy.dab-octatonic.ts.net";
          open = "env ${waylandEnv} xdg-open";
          copy = "env ${waylandEnv} wl-copy '>' '/dev/null' '2>&1'";
        };
      };

      # One arm per verb and client. The arm holds the text of an array
      # assignment, so bash parses the quotes in it instead of receiving them
      # from an expansion, where they would turn into literal characters.
      arm =
        verb: name: client:
        "    ${verb}:${name}) CMD=(ssh ${sshOpts} ${client.target} ${client.${verb}}) ;;";

      arms = concatStringsSep "\n" (
        mapAttrsToList (
          name: client: "${arm "open" name client}\n${arm "copy" name client}"
        ) clients
      );
    in
    {
      packages.tmuxBridge = pkgs.writeShellApplication {
        name = "tmux-bridge";
        text = ''
          set -u

          # set_client loads the table entry for one verb and one client into CMD.
          # An unknown name leaves CMD empty.
          set_client() {
            CMD=()
            case "$1:$2" in
          ${arms}
            esac
          }

          # set_string loads a command string into CMD. Callers pass strings from
          # the environment only, never a target.
          set_string() {
            CMD=()
            [ -n "$1" ] || return 0
            read -r -a CMD <<<"$1"
          }

          # run_cmd runs CMD with the extra arguments appended and names the
          # command on failure.
          run_cmd() {
            [ "''${#CMD[@]}" -gt 0 ] || return 1
            if ! "''${CMD[@]}" "$@" >/dev/null 2>&1; then
              printf 'tmux-bridge: %s failed\n' "''${CMD[*]}" >&2
              return 1
            fi
          }

          # session_client prints the machine this shell belongs to. It checks the
          # explicit name, then SSH_TTY, then asks tmux for the attached client.
          session_client() {
            local link name tty

            if [ -n "''${PI_CLIENT:-}" ]; then
              printf '%s\n' "$PI_CLIENT"
              return 0
            fi
            tty="''${SSH_TTY:-}"
            if [ -z "$tty" ] && [ -n "''${TMUX:-}" ]; then
              tty="$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)"
            fi
            [ -n "$tty" ] || return 0
            link="''${HOME}/.pi-clip/by-tty/''${tty##*/}.sock"
            [ -e "$link" ] || return 0
            name="$(readlink -f "$link" 2>/dev/null || printf '%s' "$link")"
            name="''${name##*/}"
            printf '%s\n' "''${name%.sock}"
          }

          fail() {
            printf 'tmux-bridge: %s\n' "$1" >&2
            exit 1
          }

          do_open() {
            local client value

            [ "$#" -gt 0 ] || fail "open needs a target"
            client="$(session_client)"
            for value in "''${PI_OPEN:-}" "''${LC_PI_OPEN:-}"; do
              set_string "$value"
              run_cmd "$@" && return 0
            done
            set_client open "$client"
            run_cmd "$@" && return 0
            for value in open xdg-open; do
              command -v "$value" >/dev/null 2>&1 || continue
              set_string "$value"
              run_cmd "$@" && return 0
            done
            fail "no opener for $*"
          }

          do_copy() {
            local buf client value

            if [ -t 0 ]; then
              fail "copy needs the selection on stdin"
            fi
            buf="$(mktemp)" || fail "mktemp failed"
            # shellcheck disable=SC2064  # Expand now: the trap fires after the
            # local buf goes out of scope.
            trap "rm -f '$buf'" EXIT
            cat >"$buf"
            client="$(session_client)"
            for value in "''${PI_COPY:-}" "''${LC_PI_COPY:-}"; do
              set_string "$value"
              run_cmd <"$buf" && return 0
            done
            set_client copy "$client"
            run_cmd <"$buf" && return 0
            # Local providers, each gated on the display server it needs.
            if [ "$(uname -s)" = Darwin ] && command -v pbcopy >/dev/null 2>&1; then
              set_string pbcopy
              run_cmd <"$buf" && return 0
            fi
            if [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
              set_string wl-copy
              run_cmd <"$buf" && return 0
            fi
            if [ -n "''${DISPLAY:-}" ]; then
              if command -v xsel >/dev/null 2>&1; then
                set_string "xsel -i --clipboard"
                run_cmd <"$buf" && return 0
              fi
              if command -v xclip >/dev/null 2>&1; then
                set_string "xclip -selection clipboard"
                run_cmd <"$buf" && return 0
              fi
            fi
            fail "no clipboard provider"
          }

          case "''${1:-}" in
            open)
              shift
              do_open "$@"
              ;;
            copy)
              shift
              do_copy
              ;;
            client)
              session_client
              ;;
            *)
              printf 'usage: tmux-bridge {open <target>|copy|client}\n' >&2
              exit 64
              ;;
          esac
        '';
      };
    };
}
