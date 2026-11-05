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
# TODO: fold the table into the pi-clip protocol once it gains open and write
# verbs. The socket is read-only today, so ssh carries these two calls.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.lib) concatStringsSep mapAttrsToList;

      # Reuse one connection per target, the same way the client ssh blocks do.
      sshCmd = "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o ControlPath=~/.ssh/cm-%r@%h:%p -o ControlPersist=yes";

      # name -> ssh target plus the opener and the copier on that machine.
      # macmini is verified live; desky and envy take their user from
      # dendritic/constants.nix.
      clients = {
        macmini = {
          target = "mattgmak@macmini.dab-octatonic.ts.net";
          open = "/usr/bin/open";
          copy = "/usr/bin/pbcopy";
        };
        desky = {
          target = "goofy@goofydesky.dab-octatonic.ts.net";
          open = "xdg-open";
          copy = "wl-copy";
        };
        envy = {
          target = "goofy@goofyenvy.dab-octatonic.ts.net";
          open = "xdg-open";
          copy = "wl-copy";
        };
      };

      # Each verb gets one case body: name -> "ssh <opts> <target> <program>".
      branch =
        verb: concatStringsSep "\n" (
          mapAttrsToList (
            name: client: "    ${name}) echo '${sshCmd} ${client.target} ${client.${verb}}' ;;"
          ) clients
        );
    in
    {
      packages.tmuxBridge = pkgs.writeShellApplication {
        name = "tmux-bridge";
        text = ''
          set -u

          # remote_open and remote_copy print the command for a client name, or
          # nothing when the name is unknown.
          remote_open() {
            case "$1" in
          ${branch "open"}
            esac
          }

          remote_copy() {
            case "$1" in
          ${branch "copy"}
            esac
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

          # try_command runs one candidate and reports the command on failure. sh -c
          # splits the string into argv, and $0 carries the command so the caller's
          # arguments stay quoted. The strings come from the tables, never from the
          # caller, so the split is safe.
          try_command() {
            local candidate="$1"
            shift
            [ -n "$candidate" ] || return 1
            if sh -c 'exec $0 "$@"' "$candidate" "$@" >/dev/null 2>&1; then
              return 0
            fi
            printf 'tmux-bridge: %s failed\n' "$candidate" >&2
            return 1
          }

          do_open() {
            local client cmd

            [ "$#" -gt 0 ] || fail "open needs a target"
            client="$(session_client)"
            for cmd in "''${PI_OPEN:-}" "''${LC_PI_OPEN:-}" "$(remote_open "$client")"; do
              try_command "$cmd" "$@" && return 0
            done
            for cmd in open xdg-open; do
              command -v "$cmd" >/dev/null 2>&1 || continue
              try_command "$cmd" "$@" && return 0
            done
            fail "no opener for $*"
          }

          do_copy() {
            local buf client cmd

            if [ -t 0 ]; then
              fail "copy needs the selection on stdin"
            fi
            buf="$(mktemp)" || fail "mktemp failed"
            # shellcheck disable=SC2064  # Expand now: the trap fires after the
            # local buf goes out of scope.
            trap "rm -f '$buf'" EXIT
            cat >"$buf"
            client="$(session_client)"
            for cmd in "''${PI_COPY:-}" "''${LC_PI_COPY:-}" "$(remote_copy "$client")"; do
              try_command "$cmd" <"$buf" && return 0
            done
            # Local providers, each gated on the display server it needs.
            if [ "$(uname -s)" = Darwin ] && command -v pbcopy >/dev/null 2>&1; then
              try_command pbcopy <"$buf" && return 0
            fi
            if [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
              try_command wl-copy <"$buf" && return 0
            fi
            if [ -n "''${DISPLAY:-}" ]; then
              if command -v xsel >/dev/null 2>&1; then
                try_command "xsel -i --clipboard" <"$buf" && return 0
              fi
              if command -v xclip >/dev/null 2>&1; then
                try_command "xclip -selection clipboard" <"$buf" && return 0
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
