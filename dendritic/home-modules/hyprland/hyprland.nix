{ inputs, self, ... }:
{
  flake.homeModules.hyprland =
    {
      pkgs,
      lib,
      config,
      hostname,
      ...
    }:
    {
      imports = [
        self.homeModules.hyprlock
        self.homeModules.hyprpaper
      ];
      home.file.".config/hypr" = {
        recursive = true;
        source = ./hypr;
      };

      home.packages = with pkgs; [
        grim
        hyprpaper
        hypridle
        hyprpicker
        hyprpolkitagent
        hyprsunset
        hdrop
        libinput
        networkmanagerapplet
        pavucontrol
        pipewire
        slurp
        swayidle
        swaylock-effects
        wl-clipboard
        wlogout
      ];
      xdg.configFile."uwsm/env".source =
        "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
      wayland.windowManager.hyprland = {
        package = null;
        portalPackage = null;
        enable = true;
        systemd.enable = false;
        systemd.variables = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_DESKTOP"
          "XDG_SESSION_TYPE"
          "DESKTOP_SESSION"
        ];

        plugins = [
          inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.csgo-vulkan-fix
        ];

        sourceFirst = true;
        settings =
          let
            deskyMonitors = {
              primary = "DP-3";
              secondary = "HDMI-A-5";
            };
            allWorkspacesIndex = lib.map (index: toString index) (lib.range 1 10);
            primaryWorkspaces = lib.take 5 allWorkspacesIndex; # ["1" "2" "3" "4" "5"]
            secondaryWorkspaces = lib.drop 5 allWorkspacesIndex; # ["6" "7" "8" "9" "10"]
            # cursorLaunchFlags =
            #   "--enable-features=UseOzonePlatform --ozone-platform=x11 --ignore-gpu-blacklist --enable-gpu-rasterization --enable-native-gpu-memory-buffers";
            electronLaunchFlags = "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --ignore-gpu-blacklist --enable-gpu-rasterization --enable-native-gpu-memory-buffers";
          in
          {
            binds = {
              scroll_event_delay = 100;
            };
            scrolling = {
              column_width = 0.7;
            };
            unbind = [ ];
            bindin = [
              # "Super, catchall, global, caelestia:launcherInterrupt"
              # "Super, mouse:272, global, caelestia:launcherInterrupt"
              # "Super, mouse:273, global, caelestia:launcherInterrupt"
              # "Super, mouse:274, global, caelestia:launcherInterrupt"
              # "Super, mouse:275, global, caelestia:launcherInterrupt"
              # "Super, mouse:276, global, caelestia:launcherInterrupt"
              # "Super, mouse:277, global, caelestia:launcherInterrupt"
              # "Super, mouse_up, global, caelestia:launcherInterrupt"
              # "Super, mouse_down, global, caelestia:launcherInterrupt"
            ];
            bindlpt = [
              # Focus binds
              "ALT, R, focuswindow, initialtitle:(Zen Browser)"
              "ALT, E, focuswindow, class:(.*[Cc]ursor.*)"
              "ALT, W, focuswindow, class:(.*ghostty.*)"
              "ALT, Z, focuswindow, class:(vesktop)"
              "ALT, O, focuswindow, class:(OrcaSlicer)"
            ];
            bind = [
              "ALT, m, global, caelestia:launcher"
              "ALT SHIFT, m, exec, rofi -show drun"
              "ALT, h, movefocus, l"
              "ALT, j, movefocus, d"
              "ALT, k, movefocus, u"
              "ALT, l, movefocus, r"
              "ALT, Up, movefocus, u"
              "ALT, Down, movefocus, d"
              "ALT SUPER, Up, layoutmsg, move -col"
              "ALT SUPER, Down, layoutmsg, move +col"
              "ALT, mouse_up, layoutmsg, move +col"
              "ALT, mouse_down, layoutmsg, move -col"
              "ALT, Left, movefocus, l"
              "ALT, Right, movefocus, r"
              "ALT SHIFT, h, movewindow, l"
              "ALT SHIFT, j, movewindow, d"
              "ALT SHIFT, k, movewindow, u"
              "ALT SHIFT, l, movewindow, r"
              "ALT SHIFT, Left, movewindow, l"
              "ALT SHIFT, Down, movewindow, d"
              "ALT SHIFT, Up, movewindow, u"
              "ALT SHIFT, Right, movewindow, r"
              "ALT, Tab, layoutmsg, cyclenext"
              "ALT SHIFT, Tab, layoutmsg, cycleprev"
              "ALT, t, togglefloating"
              "ALT, f, fullscreen"
              "ALT, d, killactive"
              "ALT, c, centerwindow"
              "ALT, G, workspace, name:Game"
              "ALT SHIFT, G, movetoworkspacesilent, name:Game"
              ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
              ", XF86AudioMicMute, exec, ~/.config/hypr/scripts/mic-toggle.sh"
              # ", XF86AudioPlay, exec, playerctl play-pause"
              # ", XF86AudioPause, exec, playerctl play-pause"
              # ", XF86AudioNext, exec, playerctl next"
              # ", XF86AudioPrev, exec, playerctl previous"
              # Waybar binds
              # "ALT SHIFT, M, exec, pkill waybar || waybar"
              # "ALT, M, exec, pkill -SIGUSR1 waybar"
              "ALT SHIFT, M, exec, caelestia shell --kill; caelestia shell -d"
              # Utility binds
              "SUPER, V, exec, ghostty --title=clipse -e clipse"
              "SUPER, B, exec, ghostty --title=bluetui -e bluetui"
              "SUPER, Q, exec, ghostty --title=btop -e btop"
              "SUPER, A, exec, ghostty --title=wiremix -e wiremix"
              "SUPER, M, exec, ghostty --title=nmtui -e nmtui"
              # ''SUPER SHIFT, S, exec, grim -g "$(slurp -w 0)" - | wl-copy''
              "Super Shift, S, global, caelestia:screenshotFreeze"
              "SUPER SHIFT, C, exec, hyprpicker -a"
              # "SUPER, N, exec, makoctl dismiss -a"
              "ALT, N, global, caelestia:clearNotifs"
              "ALT, B, exec, caelestia shell drawers toggle sidebar"
              # App launch binds
              "SUPER, R, exec, zen-beta"
              "SUPER, E, exec, cursor"
              "SUPER, W, exec, ghostty"
              "SUPER, Z, exec, vesktop ${electronLaunchFlags}"
              # hyprsunset bind
              "SUPER, F, exec, hyprctl hyprsunset temperature 4500"
              # animation bind
              "SUPER, G, exec, ~/.config/hypr/scripts/animation-toggle.nu"
              # Input toggle binds
              "SUPER, SPACE, exec, fcitx5-remote -t"
              # Consume Super+Period so it doesn't reach apps; whisper-dictation gets it via evdev
              "SUPER, period, exec, true"
              # Logout bind
              "ALT, Q, exec, wlogout"
              # Floating terminal bind
              "SUPER, T, exec, ~/.config/hypr/scripts/floating-terminal.nu"
              # Window switcher bind
              "ALT, Comma, exec, ~/.config/hypr/scripts/window-switcher.nu"
            ]
            ++ lib.concatMap (
              index:
              let
                key = if index == "10" then "0" else index;
              in
              [
                "ALT, ${key}, workspace, ${index}"
                "ALT SHIFT, ${key}, movetoworkspacesilent, ${index}"
              ]
            ) allWorkspacesIndex;
            bindm = [
              "ALT SHIFT, mouse:272, movewindow"
              "ALT, mouse:272, resizewindow"
            ];
            binde = [
              "ALT, i, resizeactive, 0 -20"
              "ALT, u, resizeactive, 0 20"
              "ALT, y, resizeactive, -20 0"
              "ALT, o, resizeactive, 20 0"
              "ALT SHIFT, i, moveactive, 0 -20"
              "ALT SHIFT, u, moveactive, 0 20"
              "ALT SHIFT, y, moveactive, -20 0"
              "ALT SHIFT, o, moveactive, 20 0"
              "ALT, Prior, resizeactive, 0 -20"
              "ALT, Next, resizeactive, 0 20"
              "ALT, Home, resizeactive, -20 0"
              "ALT, End, resizeactive, 20 0"
              "ALT SHIFT, Prior, moveactive, 0 -20"
              "ALT SHIFT, Next, moveactive, 0 20"
              "ALT SHIFT, Home, moveactive, -20 0"
              "ALT SHIFT, End, moveactive, 20 0"
              ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%+"
              ", XF86AudioLowerVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%-"
              # ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
              # ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
            ];
            bindl = [
              ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
              ", XF86MonBrightnessDown, global, caelestia:brightnessDown"
              ", XF86AudioPlay, global, caelestia:mediaToggle"
              ", XF86AudioPause, global, caelestia:mediaToggle"
              ", XF86AudioNext, global, caelestia:mediaNext"
              ", XF86AudioPrev, global, caelestia:mediaPrev"
            ];

            monitor =
              if hostname == "GoofyDesky" then
                [
                  "${deskyMonitors.primary}, 2560x1440@240.00Hz, 0x0, 1"
                  "${deskyMonitors.secondary}, 1920x1080@144.00Hz, -1080x-650, 1, transform, 3"
                ]
              else
                [
                  "eDP-1, highres, 0x0, 1"
                  ", preferred, auto-up, 1"
                ];
            workspace =
              if hostname == "GoofyDesky" then
                [
                  "name:Game, monitor:${deskyMonitors.primary}"
                  "name:1, monitor:${deskyMonitors.primary}, layout:monocle"
                  "name:6, monitor:${deskyMonitors.secondary}, layout:scrolling, layoutopt:direction:down"
                ]
                ++ lib.map (index: "name:${index}, monitor:${deskyMonitors.primary}") (lib.drop 1 primaryWorkspaces)
                ++ lib.map (index: "name:${index}, monitor:${deskyMonitors.secondary}") (
                  lib.drop 1 secondaryWorkspaces
                )
              else
                [ "name:1, layout:monocle" ];

            input = {
              kb_layout = "us";
              follow_mouse = 2;
              touchpad = {
                natural_scroll = true;
                disable_while_typing = 1;
                scroll_factor = 0.5;
              };
              sensitivity = if hostname == "GoofyDesky" then -0.3 else 0.5;
            };
            gesture = [
              "3, horizontal, scale: 0.5, workspace"
              "3, vertical, scale: 0.5, fullscreen"
            ];
            exec-once = [
              # "uwsm app -- hyprpaper"
              "systemctl --user enable --now hyprpolkitagent.service"
              # "uwsm app -- waybar"
              "uwsm app -- clipse -listen"
              "uwsm app -- fcitx5 -dr"
              "uwsm app -- fcitx5-remote -r"
              "uwsm app -- caelestia shell -d"
              (lib.mkIf (
                hostname != "GoofyDesky"
              ) "${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh")
              (lib.mkIf (hostname == "GoofyDesky") "hyprctl dispatch movecursor 1280 720")
              "uwsm app -- hyprsunset --temperature 4500"
              (lib.mkIf (hostname == "GoofyDesky") "vesktop ${electronLaunchFlags}")
              "gnome-keyring-daemon --start --components=secrets"
            ];
            xwayland = {
              enabled = true;
              force_zero_scaling = true;
            };
            decoration = {
              rounding = 10;
              blur = {
                enabled = true;
                size = 3;
                passes = 3;
              };
            };
            animations = {
              enabled = "yes";
              # bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
              bezier = "myBezier, 0.10, 0.9, 0.1, 1.05";
              animation = [
                "windows, 1, 4, myBezier"
                "windowsOut, 1, 4, myBezier"
                # "windowsOut, 1, 7, default, popin 80%"
                "border, 1, 10, default"
                "fade, 1, 4, default"
                "workspaces, 1, 3, default"
              ];
            };

            plugin = {
              csgo-vulkan-fix = {
                fix_mouse = true;
                res_w = 2560;
                res_h = 1440;
                class = "SDL Application";
                vkfix-app = [
                  "cs2, 2560, 1440"
                  "SDL Application, 2560, 1440"
                ];
              };
            };

            general = {
              # gaps_in = 2.5;
              # gaps_out = 5;
              gaps_in = 5;
              gaps_out = 10;
              resize_on_border = true;
              border_size = if hostname == "GoofyDesky" then 2 else 1;
              "col.active_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base0E})";
              "col.inactive_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
              allow_tearing = true;
            };
            cursor = {
              no_warps = true;
            };
            windowrule =
              let
                matchPip = "match:title ^(Picture-in-Picture)$";
                matchFloatingTerminal = "match:title (floating-terminal)";
                primaryWorkspacesMatcher = "match:workspace r[${lib.head primaryWorkspaces}-${lib.last primaryWorkspaces}]";
                secondaryWorkspacesMatcher = "match:workspace r[${lib.head secondaryWorkspaces}-${lib.last secondaryWorkspaces}]";
              in
              [
                "${primaryWorkspacesMatcher}, match:title (clipse|bluetui|nmtui|wiremix|window-switcher), float on, size 1200 800, center on, stay_focused on, pin on"
                "match:workspace name:Game, match:title (clipse|bluetui|nmtui|wiremix|window-switcher), float on, size 1200 800, center on, stay_focused on, pin on"
                "${primaryWorkspacesMatcher}, match:title (btop), float on, size 1600 900, center on, stay_focused on, pin on"
                "match:workspace name:Game, match:title (btop), float on, size 1600 900, center on, stay_focused on, pin on"
                "${matchPip}, pin on, float on"
                "${matchFloatingTerminal}, float on, pin on, center on, stay_focused on, size 1200 800"
                "match:class ([Cc]ursor|zen.*), focus_on_activate on"
                "match:class ([Cc]ursor), match:float true, center on"
                "match:title (window-switcher|clipse), no_anim on"
              ]
              ++ (
                if hostname == "GoofyDesky" then
                  [
                    "${matchPip}, monitor ${deskyMonitors.secondary}, no_initial_focus on, center on, size 986 555"
                    "match:class (org.prismlauncher.PrismLauncher|steam|Minecraft.*|cs2|osu!|steam_app_.*), workspace name:Game"
                    "match:class (cs2|steam_app_.*), immediate on"
                    "match:class (steam_app_.*), fullscreen on"
                    "${secondaryWorkspacesMatcher}, match:title (btop|clipse|bluetui|nmtui|wiremix), float on, size 1000 800, center on, stay_focused on, pin on"
                    "match:class (vesktop), workspace ${lib.head secondaryWorkspaces}"
                  ]
                else
                  [ ]
              );
          };
      };
      xdg.portal = {
        enable = lib.mkForce true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-hyprland
          xdg-desktop-portal-gtk
        ];
      };
    };
}
