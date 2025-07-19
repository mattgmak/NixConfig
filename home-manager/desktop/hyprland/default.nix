{ pkgs, lib, config, hostname, ... }: {
  imports = [ ./hyprlock.nix ./hyprpaper.nix ./hypridle.nix ];
  home.file.".config/hypr" = {
    recursive = true;
    source = ./hypr;
  };

  home.packages = with pkgs; [
    grim
    hyprland
    hyprpaper
    hypridle
    hyprpicker
    hyprpolkitagent
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
    package = null;
    portalPackage = null;
    enable = true;
    systemd.enable = true;
    systemd.variables = [
      "DISPLAY"
      "HYPRLAND_INSTANCE_SIGNATURE"
      "WAYLAND_DISPLAY"
      "XDG_CURRENT_DESKTOP"
      "XDG_SESSION_DESKTOP"
      "XDG_SESSION_TYPE"
      "DESKTOP_SESSION"
    ];

    sourceFirst = true;
    settings = {
      "$mod" = "ALT";
      unbind = [ ];
      bind = [
        "$mod, h, exec, rofi -show drun"
        "$mod, j, movefocus, u"
        "$mod, k, movefocus, d"
        "$mod, l, movefocus, l"
        "$mod, semicolon, movefocus, r"
        "$mod, UP, movefocus, u"
        "$mod, DOWN, movefocus, d"
        "$mod, LEFT, movefocus, l"
        "$mod, RIGHT, movefocus, r"
        "$mod SHIFT, j, movewindow, u"
        "$mod SHIFT, k, movewindow, d"
        "$mod SHIFT, l, movewindow, l"
        "$mod SHIFT, semicolon, movewindow, r"
        "$mod SHIFT, UP, movewindow, u"
        "$mod SHIFT, DOWN, movewindow, d"
        "$mod SHIFT, LEFT, movewindow, l"
        "$mod SHIFT, RIGHT, movewindow, r"
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
        "$mod SHIFT, 1, movetoworkspacesilent, 1"
        "$mod SHIFT, 2, movetoworkspacesilent, 2"
        "$mod SHIFT, 3, movetoworkspacesilent, 3"
        "$mod SHIFT, 4, movetoworkspacesilent, 4"
        "$mod SHIFT, 5, movetoworkspacesilent, 5"
        "$mod SHIFT, 6, movetoworkspacesilent, 6"
        "$mod SHIFT, 7, movetoworkspacesilent, 7"
        "$mod SHIFT, 8, movetoworkspacesilent, 8"
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
        ''SUPER SHIFT, S, exec, grim -g "$(slurp -w 0)" - | wl-copy''
        "SUPER SHIFT, C, exec, hyprpicker -a"
        "SUPER, N, exec, makoctl dismiss -a"
        # App launch binds
        "SUPER, R, exec, zen"
        "SUPER, E, exec, cursor"
        "SUPER, W, exec, ghostty"
        "SUPER, C, exec, vesktop"
        # Focus binds
        "$mod, R, focuswindow, class:(.*zen-beta.*)"
        "$mod, E, focuswindow, class:(.*[Cc]ursor.*)"
        "$mod, W, focuswindow, class:(.*ghostty.*)"
        "$mod, C, focuswindow, class:(vesktop)"
        "$mod, G, workspace, name:Game"
        # Input toggle binds
        "SUPER, SPACE, exec, fcitx5-remote -t"
        # Logout bind
        "$mod, Q, exec, wlogout"
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
        "$mod, PAGEUP, resizeactive, 0 -20"
        "$mod, PAGEDOWN, resizeactive, 0 20"
        "$mod, HOME, resizeactive, -20 0"
        "$mod, END, resizeactive, 20 0"
        "$mod SHIFT, PAGEUP, moveactive, 0 -20"
        "$mod SHIFT, PAGEDOWN, moveactive, 0 20"
        "$mod SHIFT, HOME, moveactive, -20 0"
        "$mod SHIFT, END, moveactive, 20 0"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      monitor = if hostname == "GoofyDesky" then [
        "DP-3, 2560x1440@240.00Hz, 0x0, 1"
        "HDMI-A-5, 1920x1080@144.00Hz, -1080x-650, 1, transform, 3"
      ] else [
        "eDP-1, highres, 0x0, 1"
        ", preferred, auto-up, 1"
      ];
      workspace = if hostname == "GoofyDesky" then [
        "name:1, monitor:DP-3"
        "name:Game, monitor:DP-3"
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
        "hyprpaper"
        "systemctl --user start hyprpolkitagent"
        "clipse -listen"
        "fcitx5 -dr"
        "fcitx5-remote -r"
        "${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh"
        "hyprctl dispatch workspace 1"
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
          "windows, 1, 5, myBezier"
          "windowsOut, 1, 5, myBezier"
          # "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
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
      };
      cursor = { no_warps = true; };
      windowrule = let matchPip = "title:^(Picture-in-Picture)$";
      in [
        "float, title:(clipse|bluetui|nmtui|btop)"
        "size 1200 800, title:(clipse|bluetui|nmtui)"
        "size 1600 900, title:(btop)"
        "float, ${matchPip}"
        "pin, ${matchPip}"
      ] ++ (if hostname == "GoofyDesky" then [
        "monitor HDMI-A-5, ${matchPip}"
        "size 100% 40%, ${matchPip}"
        "noinitialfocus, ${matchPip}"
        "workspace name:Game, class:(org.prismlauncher.PrismLauncher)"
      ] else
        [ ]);
    };
  };
}
