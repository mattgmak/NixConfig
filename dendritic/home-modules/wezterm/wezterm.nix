{
  flake.homeModules.wezterm =
    { ... }:
    {
      stylix.targets.wezterm.enable = true;

      programs.wezterm = {
        enable = true;
        extraConfig = builtins.readFile ./config/wezterm.lua;
      };

      home.file.".config/wezterm/modules" = {
        source = ./config/modules;
        recursive = true;
      };
    };
}
