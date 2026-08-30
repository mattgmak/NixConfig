{
  flake.homeModules.mangohud =
    { pkgs, ... }:
    let
      toggleScript = pkgs.writeShellScript "mangohud-toggle" ''
        STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/mangohud-visible"
        SOCAT=${pkgs.socat}/bin/socat

        notify_toggled() {
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
        }

        # gamescope --mangoapp: overlay in mangoapp, toggled from host via mangohudctl.
        if pgrep -x mangoapp >/dev/null 2>&1 && command -v mangohudctl >/dev/null 2>&1; then
          mangohudctl toggle no_display
          notify_toggled
          exit 0
        fi

        # Explicit mangohud (vkcube, etc.): per-process control sockets.
        toggled=0
        while IFS= read -r sock; do
          if printf ':hud;' | "$SOCAT" -T1 - "ABSTRACT-CONNECT:$sock" 2>/dev/null; then
            toggled=$((toggled + 1))
          fi
        done < <(
          awk 'NR>1 { print $NF }' /proc/net/unix \
            | grep '^@mangohud' \
            | sed 's/^@//' \
            | sort -u
        )

        if [ "$toggled" -gt 0 ]; then
          notify_toggled
          exit 0
        fi

        notify-send "MangoHud" "No overlay — set Steam launch options to: steam-gamescope %command%" -t 5000
      '';

      # GoofyDesky primary panel; used for Steam games that need mangoapp (EAC, etc.).
      steamGamescope = pkgs.writeShellScriptBin "steam-gamescope" ''
        exec ${pkgs.gamescope}/bin/gamescope \
          -f \
          -W 2560 \
          -H 1440 \
          -r 240 \
          --mangoapp \
          -- "$@"
      '';
    in
    {
      home.packages = [
        pkgs.socat
        steamGamescope
      ];

      home.file.".config/hypr/scripts/mangohud-toggle.sh".source = toggleScript;

      programs.mangohud = {
        enable = true;
        # Session-wide LD_PRELOAD cannot be toggled from Hyprland in Steam/EAC sandboxes.
        # Use steam-gamescope for games; mangohud prefix for standalone tools if needed.
        enableSessionWide = false;
        settings = {
          hud_no_display = 1;
          control = "mangohud-%p";
        };
      };
    };
}
