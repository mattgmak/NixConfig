{ inputs, ... }:
{
  flake.homeModules.hyprgrass =
    {
      pkgs,
      lib,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      wayland.windowManager.hyprland = {
        plugins = lib.mkAfter [
          inputs.hyprgrass.packages.${system}.default
        ];

        settings = {
          gestures = {
            workspace_swipe_touch = true;
            workspace_swipe_cancel_ratio = 0.15;
          };

          plugin = {
            touch_gestures = {
              sensitivity = 4.0;
              workspace_swipe_fingers = 3;
              workspace_swipe_edge = "none";
              long_press_delay = 400;
              resize_on_border_long_press = true;
              edge_margin = 10;
              hyprgrass-bind = [
                # Workspace
                # ", edge:r:l, workspace, +1"
                # ", edge:l:r, workspace, -1"

                # Window management
                ", swipe:3:u, fullscreen"
                ", swipe:3:d, togglefloating"
                ", swipe:3:ru, centerwindow"
                ", swipe:4:d, killactive"
                ", swipe:4:u, layoutmsg, cyclenext"
                ", swipe:4:r, layoutmsg, cycleprev"

                # Launchers
                ", tap:3, global, caelestia:launcher"
                ", tap:4, exec, rofi -show drun"
                ", tap:5, exec, ~/.config/hypr/scripts/window-switcher.nu"
              ];
              hyprgrass-bindm = [
                ", longpress:2, movewindow"
                ", longpress:3, resizewindow"
              ];
            };
          };
        };
      };
    };
}
