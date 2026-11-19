{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.yaziClipboard = pkgs.writeShellApplication {
        name = "yazi-clipboard";
        runtimeInputs = [ pkgs.file ];
        text = /* bash */ ''
          set -eu

          # Pick the tool the session has. cb maps a visible window on Hyprland,
          # so it steals focus, and it offers a PNG as text/plain, so the clipboard
          # holds the path. wl-copy and pbcopy have neither fault.
          if [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
            tool=wl-copy
          elif command -v pbcopy >/dev/null 2>&1; then
            tool=pbcopy
          elif command -v cb >/dev/null 2>&1; then
            tool=cb
          else
            printf 'yazi-clipboard: no clipboard tool found\n' >&2
            exit 1
          fi

          for p in "$@"; do
            m="$(file -b --mime-type "$p")"
            case "$m" in
              image/*)
                case "$tool" in
                  wl-copy) wl-copy -t "$m" <"$p" ;;
                  pbcopy) pbcopy <"$p" ;;
                  cb) cb copy "$p" ;;
                esac
                ;;
              *)
                case "$tool" in
                  wl-copy) printf 'file://%s\n' "$p" | wl-copy -t text/uri-list ;;
                  pbcopy) printf 'file://%s\n' "$p" | pbcopy ;;
                  cb) cb copy "$p" ;;
                esac
                ;;
            esac
          done
        '';
      };
    };
}
