{ pkgs, ... }:
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
      "$mod, 4, workspace, 4"
      "$mod, 5, workspace, 5"
      "$mod, 6, workspace, 6"
      "$mod, 7, workspace, 7"
      "$mod, 8, workspace, 8"
      "$mod, 9, workspace, 9"
      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "$mod SHIFT, 4, movetoworkspace, 4"
      "$mod SHIFT, 5, movetoworkspace, 5"
      "$mod SHIFT, 6, movetoworkspace, 6"
      "$mod SHIFT, 7, movetoworkspace, 7"
      "$mod SHIFT, 8, movetoworkspace, 8"
      "$mod SHIFT, 9, movetoworkspace, 9"
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
      # ", XF86AudioRaiseVolume, exec, pulseaudio-ctl up"
      # ", XF86AudioLowerVolume, exec, pulseaudio-ctl down"
      # ", XF86AudioMute, exec, pulseaudio-ctl mute"
      ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
      ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ", XF86KbdBrightnessUp, exec, brightnessctl set 5%+"
      ", XF86KbdBrightnessDown, exec, brightnessctl set 5%-"
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
