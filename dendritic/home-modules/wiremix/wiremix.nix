{
  flake.homeModules.wiremix =
    { pkgs, ... }:
    {
      home.file.".config/wiremix/wiremix.toml" = {
        source = ./wiremix.toml;
      };

      # wiremix loops on "Initializing..." until its first PipeWire sync
      # returns. A slow or blocked daemon leaves it there without a limit, so
      # probe first and restart the user units when the probe fails.
      home.packages = [
        (pkgs.writeShellApplication {
          name = "wiremix-run";
          runtimeInputs = with pkgs; [
            coreutils
            pipewire
            systemd
          ];
          text = ''
            log="''${XDG_STATE_HOME:-$HOME/.local/state}/wiremix-run.log"
            mkdir -p "$(dirname "$log")"

            probe() {
              timeout 5 pw-cli info 0 >/dev/null 2>&1
            }

            if ! probe && ! probe; then
              printf '%s pipewire silent, restart user units\n' "$(date -Is)" >>"$log"
              systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service >>"$log" 2>&1 || true
              tries=0
              while [ "$tries" -lt 15 ]; do
                if probe; then break; fi
                sleep 1
                tries=$((tries + 1))
              done
              if ! probe; then
                printf 'PipeWire does not answer. Log: %s\n' "$log"
                read -r _ || true
                exit 1
              fi
            fi

            exec wiremix "$@"
          '';
        })
      ];
    };
}
