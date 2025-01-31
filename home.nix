{ config, pkgs, ... }:

let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
  '';
in {
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.packages = with pkgs; [ hello ];

  home.file = { };

  home.sessionVariables = { };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "ALT";
    unbind = [];
    bind = [
      "$mod, Return, exec, wezterm"
      "$mod, h, exec, rofi -show drun"
      "$mod, P, exec, rofi -show pmenu"
      "$mod, j, movefocus, u"
      "$mod, k, movefocus, d"
      "$mod, l, movefocus, l"
      "$mod, semicolon, movefocus, r"
      "$mod, u, resizeactive, 0 -10.0"
      "$mod, i, resizeactive, 0 10.0"
      "$mod, o, resizeactive, -10.0 0"
      "$mod, p, resizeactive, 10.0 0"
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
      "$mod, Tab, cyclenext"
      "$mod, t, togglefloating"
      "$mod, f, fullscreen"
      "$mod, d, killactive"
      "$mod, q, exit"
    ];
    # bindm = [ "$mod, mouse:272, movewindow" "$mod, mouse:273, resizewindow" ];
    monitor = ", highres, 0x0, 1";
    input = {
      kb_layout = "us";
      follow_mouse = 0;
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
    general = {
      gaps_in = 2;
      gaps_out = 2;
    };
    cursor = { no_warps = true; };
  };
}
