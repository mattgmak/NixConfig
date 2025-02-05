{ config, pkgs, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
    clipse -listen &
  '';
in {
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "ALT";
    unbind = [ ];
    bind = [
      "$mod, Return, exec, wezterm"
      "$mod, h, exec, rofi -show drun"
      # "$mod, P, exec, rofi -show pmenu"
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
      "SUPER, q, exit"
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "SUPER, V, exec, wezterm start --class clipse -e clipse"
    ];
    bindm = [ "$mod, mouse:272, movewindow" "$mod, mouse:273, resizewindow" ];
    binde = [
      "$mod, u, resizeactive, 0 -20"
      "$mod, i, resizeactive, 0 20"
      "$mod, o, resizeactive, -20 0"
      "$mod, p, resizeactive, 20 0"
      "$mod SHIFT, u, moveactive, 0 -20"
      "$mod SHIFT, i, moveactive, 0 20"
      "$mod SHIFT, o, moveactive, -20 0"
      "$mod SHIFT, p, moveactive, 20 0"
      "$mod, XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
      "$mod, XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"
      "$mod, XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ];

    monitor = ", highres, 0x0, 1";
    input = {
      kb_layout = "us";
      follow_mouse = 2;
      touchpad = {
        natural_scroll = true;
        disable_while_typing = 1;
        scroll_factor = 0.5;
      };
      sensitivity = 0.5;
    };
    exec-once = "${startupScript}/bin/start";
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
      bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
      animation = [
        "windows, 1, 5, myBezier"
        "windowsOut, 1, 7, default, popin 80%"
        "border, 1, 10, default"
        "fade, 1, 7, default"
        "workspaces, 1, 6, default"
      ];
    };
    general = {
      gaps_in = 2;
      gaps_out = 2;
    };
    cursor = { no_warps = true; };
    windowrulev2 = [ "float,class:(clipse)" "size 1000 800,class:(clipse)" ];
  };
}
