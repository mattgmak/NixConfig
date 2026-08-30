{
  flake.homeModules.mangohud =
    { pkgs, ... }:
    let
      toggleScript = pkgs.writeShellScript "mangohud-toggle" ''
        STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/mangohud-visible"
        SOCAT=${pkgs.socat}/bin/socat

        discover_sockets() {
          awk 'NR>1 { print $NF }' /proc/net/unix \
            | grep '^@mangohud' \
            | sed 's/^@//' \
            | sort -u
        }

        toggle_socket() {
          printf ':hud;' | "$SOCAT" -T1 - "ABSTRACT-CONNECT:$1" 2>/dev/null
        }

        toggled=0
        while IFS= read -r sock; do
          if toggle_socket "$sock"; then
            toggled=$((toggled + 1))
          fi
        done < <(discover_sockets)

        if [ "$toggled" -gt 0 ]; then
          visible=0
          if [ -f "$STATE_FILE" ]; then
            visible=$(<"$STATE_FILE")
          fi

          if [ "$visible" = "1" ]; then
            echo 0 >"$STATE_FILE"
            notify-send "MangoHud hidden" -t 2000
          else
            echo 1 >"$STATE_FILE"
            notify-send "MangoHud shown" -t 2000
          fi
        elif command -v mangohudctl >/dev/null 2>&1; then
          mangohudctl toggle no_display

          visible=0
          if [ -f "$STATE_FILE" ]; then
            visible=$(<"$STATE_FILE")
          fi

          if [ "$visible" = "1" ]; then
            echo 0 >"$STATE_FILE"
            notify-send "MangoHud hidden" -t 2000
          else
            echo 1 >"$STATE_FILE"
            notify-send "MangoHud shown" -t 2000
          fi
        else
          notify-send "MangoHud" "No MangoHud instances running" -t 2000
        fi
      '';
    in
    {
      home.packages = [ pkgs.socat ];

      home.file.".config/hypr/scripts/mangohud-toggle.sh".source = toggleScript;

      programs.mangohud = {
        enable = true;
        enableSessionWide = true;
        settings = {
          hud_no_display = 1;
          # Per-process control socket; toggle script broadcasts :hud; to all instances.
          control = "mangohud-%p";
        };
      };
    };
}
