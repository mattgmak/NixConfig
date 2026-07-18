{
  flake.nixosModules.ardour =
    {
      pkgs,
      lib,
      username,
      ...
    }:
    let
      makePluginPath =
        format:
        (lib.makeSearchPath format [
          "$HOME/.nix-profile/lib"
          "/run/current-system/sw/lib"
          "/etc/profiles/per-user/$USER/lib"
        ])
        + ":$HOME/.${format}";

      guitarMonitor = pkgs.writeShellApplication {
        name = "guitar-monitor";
        runtimeInputs = with pkgs; [
          pipewire
          pulseaudio
        ];
        text = ''
          set -euo pipefail

          state_file="''${XDG_RUNTIME_DIR:-/tmp}/guitar-monitor.loopback"

          is_monitor_source() {
            case "$1" in
              *.monitor) return 0 ;;
              *) return 1 ;;
            esac
          }

          list_capture_sources() {
            pactl list sources short | while read -r _ name _rest; do
              if ! is_monitor_source "$name"; then
                printf '%s\n' "$name"
              fi
            done
          }

          list_playback_sinks() {
            pactl list sinks short | while read -r _ name _rest; do
              if ! is_monitor_source "$name"; then
                printf '%s\n' "$name"
              fi
            done
          }

          source_description() {
            pactl list sources | awk -v target="$1" '
              $1 == "Name:" && $2 == target { found=1; next }
              found && $1 == "Description:" {
                $1 = ""
                sub(/^ /, "")
                print
                exit
              }
            '
          }

          sink_description() {
            pactl list sinks | awk -v target="$1" '
              $1 == "Name:" && $2 == target { found=1; next }
              found && $1 == "Description:" {
                $1 = ""
                sub(/^ /, "")
                print
                exit
              }
            '
          }

          matching_sink() {
            local source="$1"
            local card

            card=$(echo "$source" | sed -n 's/alsa_input\.\([^-]*-[^-]*\).*/\1/p')
            if [ -z "$card" ]; then
              card=$(echo "$source" | sed -n 's/alsa_input\.\([^-]*\).*/\1/p')
            fi

            if [ -n "$card" ]; then
              list_playback_sinks | awk -v card="$card" 'index($0, card) { print; exit }'
            fi
          }

          choose_from_list() {
            local prompt="$1"
            shift
            local -a items=("$@")

            if [ "''${#items[@]}" -eq 0 ]; then
              return 1
            fi

            if [ "''${#items[@]}" -eq 1 ]; then
              echo "''${items[0]}"
              return 0
            fi

            echo "$prompt" >&2
            local i=1
            for item in "''${items[@]}"; do
              printf '  %d) %s\n' "$i" "$item" >&2
              i=$((i + 1))
            done

            while true; do
              printf 'Choice [1-%s]: ' "''${#items[@]}" >&2
              read -r choice
              if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "''${#items[@]}" ]; then
                echo "''${items[$((choice - 1))]}"
                return 0
              fi
              echo "Invalid choice, try again." >&2
            done
          }

          choose_source() {
            local -a names=()
            local -a labels=()
            local name desc

            while IFS= read -r name; do
              [ -z "$name" ] && continue
              desc=$(source_description "$name")
              names+=("$name")
              labels+=("$desc ($name)")
            done < <(list_capture_sources)

            if [ "''${#names[@]}" -eq 0 ]; then
              echo "No capture devices found." >&2
              return 1
            fi

            local pick
            pick=$(choose_from_list "Select input to monitor:" "''${labels[@]}")
            local i
            for i in "''${!labels[@]}"; do
              if [ "''${labels[$i]}" = "$pick" ]; then
                echo "''${names[$i]}"
                return 0
              fi
            done
          }

          choose_sink() {
            local source="$1"
            local suggested
            suggested=$(matching_sink "$source" || true)

            local -a names=()
            local -a labels=()
            local name desc

            if [ -n "$suggested" ]; then
              desc=$(sink_description "$suggested")
              names+=("$suggested")
              labels+=("$desc ($suggested) [matched]")
            fi

            names+=("@DEFAULT_SINK@")
            labels+=("System default output (@DEFAULT_SINK@)")

            while IFS= read -r name; do
              [ -z "$name" ] && continue
              [ "$name" = "$suggested" ] && continue
              desc=$(sink_description "$name")
              names+=("$name")
              labels+=("$desc ($name)")
            done < <(list_playback_sinks)

            local pick
            pick=$(choose_from_list "Select output for monitoring:" "''${labels[@]}")
            local i
            for i in "''${!labels[@]}"; do
              if [ "''${labels[$i]}" = "$pick" ]; then
                echo "''${names[$i]}"
                return 0
              fi
            done
          }

          read_state() {
            current_module=""
            current_source=""
            current_sink=""
            if [ -f "$state_file" ]; then
              {
                IFS= read -r current_module || true
                IFS= read -r current_source || true
                IFS= read -r current_sink || true
              } < "$state_file"
            fi
          }

          write_state() {
            local module_id="$1"
            local source="$2"
            local sink="$3"
            printf '%s\n%s\n%s\n' "$module_id" "$source" "$sink" > "$state_file"
          }

          monitor_on() {
            read_state
            if [ -n "$current_module" ]; then
              echo "Guitar monitor already on: $current_source -> $current_sink (module $current_module)"
              return 0
            fi

            local source sink module_id
            source="''${1:-}"
            sink="''${2:-}"

            if [ -z "$source" ]; then
              source=$(choose_source) || return 1
            fi

            if [ -z "$sink" ]; then
              if [ -t 0 ]; then
                sink=$(choose_sink "$source") || return 1
              else
                sink=$(matching_sink "$source" || true)
                sink="''${sink:-@DEFAULT_SINK@}"
              fi
            fi

            module_id=$(pactl load-module module-loopback \
              source="$source" \
              sink="$sink" \
              latency_msec=20 \
              source_dont_move=true \
              sink_dont_move=true)

            write_state "$module_id" "$source" "$sink"
            echo "Guitar monitor on: $source -> $sink (module $module_id)"
          }

          monitor_off() {
            read_state
            if [ -z "$current_module" ]; then
              echo "Guitar monitor is off"
              return 0
            fi

            pactl unload-module "$current_module" || true
            rm -f "$state_file"
            echo "Guitar monitor off"
          }

          show_status() {
            read_state
            if [ -n "$current_module" ]; then
              echo "on"
              echo "source: $current_source"
              echo "sink: $current_sink"
              echo "module: $current_module"
            else
              echo "off"
            fi

            echo
            echo "Available capture devices:"
            local name desc
            while IFS= read -r name; do
              [ -z "$name" ] && continue
              desc=$(source_description "$name")
              printf '  - %s (%s)\n' "$desc" "$name"
            done < <(list_capture_sources)
          }

          usage() {
            cat <<'EOF' >&2
          Usage: guitar-monitor [on|off|toggle|status] [source] [sink]

            on       Start monitoring (interactive device picker when run in a TTY)
            off      Stop monitoring
            toggle   Turn monitoring off, or start with the interactive picker
            status   Show current routing and available capture devices

          Examples:
            guitar-monitor on
            guitar-monitor on alsa_input.usb-Focusrite_Scarlett-00.HiFi__source:input_0
          EOF
          }

          case "''${1:-on}" in
            on) monitor_on "''${2:-}" "''${3:-}" ;;
            off) monitor_off ;;
            toggle)
              read_state
              if [ -n "$current_module" ]; then
                monitor_off
              else
                monitor_on "''${2:-}" "''${3:-}"
              fi
              ;;
            status) show_status ;;
            -h|--help|help) usage ;;
            *)
              usage
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      security.pam.loginLimits = [
        {
          domain = "@audio";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "99";
        }
        {
          domain = "@audio";
          item = "nice";
          type = "-";
          value = "-19";
        }
      ];

      users.users.${username}.extraGroups = [ "audio" ];

      environment.variables = {
        LV2_PATH = makePluginPath "lv2";
        VST3_PATH = makePluginPath "vst3";
        CLAP_PATH = makePluginPath "clap";
      };

      environment.systemPackages = with pkgs; [
        ardour
        qpwgraph
        lsp-plugins
        pavucontrol
        guitarMonitor
      ];

      # Keep USB audio interfaces awake; use `guitar-monitor on` for input loopback.
      services.pipewire.wireplumber.extraConfig."51-usb-guitar" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-.*"; }
              { "node.name" = "~alsa_output.usb-.*"; }
            ];
            actions = {
              "update-props" = {
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };

      boot.kernelParams = [ "usbcore.autosuspend=-1" ];
    };
}
