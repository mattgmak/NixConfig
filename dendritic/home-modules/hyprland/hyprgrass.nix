{ inputs, ... }:
{
  flake.homeModules.hyprgrass =
    {
      pkgs,
      lib,
      ...
    }:
    {
      wayland.windowManager.hyprland = {
        plugins = lib.mkAfter [
          pkgs.hyprlandPlugins.hyprgrass
        ];

        extraConfig = lib.mkOrder 900 (import ./lua/hyprgrass.nix);
      };
    };
}
