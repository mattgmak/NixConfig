{ pkgs, lib, config, hostname, inputs, ... }: {
  imports = [ ./hyprlock.nix ./hyprpaper.nix ./hypridle.nix ./hyprsunset.nix ];
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

  wayland.windowManager.hyprland = {
    package =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
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

    plugins =
      [ inputs.hyprland-plugins.packages.${pkgs.system}.csgo-vulkan-fix ];

    sourceFirst = true;
    settings = let
      deskyMonitors = {
        primary = "DP-3";
        secondary = "HDMI-A-5";
      };
    in {
      "$mod" = "ALT";
      unbind = [ ];
      bind = [
        "$mod SHIFT, h, exec, rofi -show drun"
        "$mod, h, exec, sherlock"
        "$mod, y, exec, ${config.home.homeDirectory}/.config/sherlock/switch-windows.nu"
        "$mod, j, movefocus, u"
        "$mod, k, movefocus, d"
        "$mod, l, movefocus, l"
        "$mod, semicolon, movefocus, r"
        "$mod, Up, movefocus, u"
        "$mod, Down, movefocus, d"
        "$mod, Left, movefocus, l"
        "$mod, Right, movefocus, r"
        "$mod SHIFT, j, movewindow, u"
        "$mod SHIFT, k, movewindow, d"
        "$mod SHIFT, l, movewindow, l"
        "$mod SHIFT, semicolon, movewindow, r"
        "$mod SHIFT, Up, movewindow, u"
        "$mod SHIFT, Down, movewindow, d"
        "$mod SHIFT, Left, movewindow, l"
        "$mod SHIFT, Right, movewindow, r"
        "$mod, Tab, focuscurrentorlast"
        "$mod, t, togglefloating"
        "$mod, f, fullscreen"
        "$mod, d, killactive"
        "$mod SUPER, q, exit"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, G, workspace, name:Game"
        "$mod SHIFT, 1, movetoworkspacesilent, 1"
        "$mod SHIFT, 2, movetoworkspacesilent, 2"
        "$mod SHIFT, 3, movetoworkspacesilent, 3"
        "$mod SHIFT, 4, movetoworkspacesilent, 4"
        "$mod SHIFT, 5, movetoworkspacesilent, 5"
        "$mod SHIFT, 6, movetoworkspacesilent, 6"
        "$mod SHIFT, 7, movetoworkspacesilent, 7"
        "$mod SHIFT, 8, movetoworkspacesilent, 8"
        "$mod SHIFT, G, movetoworkspacesilent, name:Game"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, ~/.config/hypr/scripts/mic-toggle.sh"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        # Waybar binds
        "$mod SHIFT, M, exec, pkill waybar || waybar"
        "$mod, M, exec, pkill -SIGUSR1 waybar"
        # Utility binds
        "SUPER, V, exec, ghostty --title=clipse -e clipse"
        "SUPER, B, exec, ghostty --title=bluetui -e bluetui"
        "SUPER, Q, exec, ghostty --title=btop -e btop"
        "SUPER, A, exec, ghostty --title=wiremix -e wiremix"
        "SUPER, M, exec, ghostty --title=nmtui -e nmtui"
        ''SUPER SHIFT, S, exec, grim -g "$(slurp -w 0)" - | wl-copy''
        "SUPER SHIFT, C, exec, hyprpicker -a"
        "SUPER, N, exec, makoctl dismiss -a"
        # App launch binds
        "SUPER, R, exec, zen"
        "SUPER, E, exec, cursor --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime"
        "SUPER, W, exec, ghostty"
        "SUPER, C, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime"
        # Focus binds
        "$mod, R, focuswindow, initialtitle:(Zen Browser)"
        "$mod, E, focuswindow, class:(.*[Cc]ursor.*)"
        "$mod, W, focuswindow, class:(.*ghostty.*)"
        "$mod, C, focuswindow, class:(vesktop)"
        # Input toggle binds
        "SUPER, SPACE, exec, fcitx5-remote -t"
        # Logout bind
        "$mod, Q, exec, wlogout"
        # Floating terminal bind
        "SUPER, T, exec, ~/.config/hypr/scripts/floating-terminal.nu"
      ];
      bindm =
        [ "$mod SHIFT, mouse:272, movewindow" "$mod, mouse:272, resizewindow" ];
      binde = [
        "$mod, u, resizeactive, 0 -20"
        "$mod, i, resizeactive, 0 20"
        "$mod, o, resizeactive, -20 0"
        "$mod, p, resizeactive, 20 0"
        "$mod SHIFT, u, moveactive, 0 -20"
        "$mod SHIFT, i, moveactive, 0 20"
        "$mod SHIFT, o, moveactive, -20 0"
        "$mod SHIFT, p, moveactive, 20 0"
        "$mod, Prior, resizeactive, 0 -20"
        "$mod, Next, resizeactive, 0 20"
        "$mod, Home, resizeactive, -20 0"
        "$mod, End, resizeactive, 20 0"
        "$mod SHIFT, Prior, moveactive, 0 -20"
        "$mod SHIFT, Next, moveactive, 0 20"
        "$mod SHIFT, Home, moveactive, -20 0"
        "$mod SHIFT, End, moveactive, 20 0"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      monitor = if hostname == "GoofyDesky" then [
        "${deskyMonitors.primary}, 2560x1440@240.00Hz, 0x0, 1"
        "${deskyMonitors.secondary}, 1920x1080@144.00Hz, -1080x-650, 1, transform, 3"
      ] else [
        "eDP-1, highres, 0x0, 1"
        ", preferred, auto-up, 1"
      ];
      workspace = if hostname == "GoofyDesky" then [
        "name:Game, monitor:${deskyMonitors.primary}"
        "name:1, monitor:${deskyMonitors.primary}"
        "name:2, monitor:${deskyMonitors.primary}"
        "name:3, monitor:${deskyMonitors.primary}"
        "name:4, monitor:${deskyMonitors.secondary}"
        "name:5, monitor:${deskyMonitors.secondary}"
        "name:6, monitor:${deskyMonitors.secondary}"
      ] else
        [ ];

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
      gestures = {
        workspace_swipe = true;
        workspace_swipe_touch = true;
      };
      exec-once = [
        "uwsm app -- hyprpaper"
        "systemctl --user start hyprpolkitagent"
        "uwsm app -- waybar"
        "uwsm app -- clipse -listen"
        "uwsm app -- fcitx5 -dr"
        "uwsm app -- fcitx5-remote -r"
        (lib.mkIf (hostname != "GoofyDesky")
          "${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh")
        (lib.mkIf (hostname == "GoofyDesky")
          "hyprctl dispatch movecursor 1280 720")
        "uwsm app -- hyprsunset"
        "hyprctl hyprsunset temperature 4500"
        (lib.mkIf (hostname == "GoofyDesky") "vesktop")
      ];
      xwayland = {
        enabled = true;
        force_zero_scaling = true;
      };
      decoration = {
        rounding = 6;
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
          res_w = 2560;
          res_h = 1440;
          class = "cs2";
        };
      };

      general = {
        gaps_in = 2.5;
        gaps_out = 5;
        resize_on_border = true;
        border_size = if hostname == "GoofyDesky" then 2 else 1;
        "col.active_border" =
          lib.mkForce "rgb(${config.lib.stylix.colors.base0E})";
        "col.inactive_border" =
          lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
        allow_tearing = true;
      };
      cursor = { no_warps = true; };
      windowrule = let
        matchPip = "title:^(Picture-in-Picture)$";
        matchFloatingTerminal = "title:(floating-terminal)";
      in [
        "float, title:(clipse|bluetui|nmtui|btop|wiremix)"
        "size 1200 800, title:(clipse|bluetui|nmtui|wiremix), onworkspace:r[1-3]"
        "size 1600 900, title:(btop), onworkspace:r[1-3]"
        "float, ${matchPip}"
        "pin, ${matchPip}"
        "center, floating:1, title:(Cursor)"
        "float, ${matchFloatingTerminal}"
        "size 60% 70%, ${matchFloatingTerminal}"
        "pin, ${matchFloatingTerminal}"
        "center, ${matchFloatingTerminal}"
        "stayfocused, ${matchFloatingTerminal}"
      ] ++ (if hostname == "GoofyDesky" then [
        "monitor ${deskyMonitors.secondary}, ${matchPip}"
        "size 100% 32%, ${matchPip}"
        "move 0 50, ${matchPip}"
        "noinitialfocus, ${matchPip}"
        "workspace name:Game, class:(org.prismlauncher.PrismLauncher|steam|Minecraft.*|cs2|osu!)"
        "immediate, class:^(cs2)$"
        "fullscreen, class:^(cs2)$"
        "size 1000 800, title:(btop|clipse|bluetui|nmtui|wiremix), onworkspace:r[4-6]"
        "workspace 4, class:(vesktop)"
      ] else
        [ ]);
    };
  };
}
