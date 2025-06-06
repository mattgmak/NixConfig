{ pkgs, ... }: {
  stylix.targets.rofi.enable = false;
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "IosevkaTerm Nerd Font";
    location = "center";
    terminal = "kitty";
    plugins = [ pkgs.rofi-calc ];
    theme = "~/.config/rofi/launcher.rasi";
  };
  home.file.".config/rofi" = {
    recursive = true;
    source = ./custom;
  };
}
