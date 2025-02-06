{ config, pkgs, ... }: {
  imports = [
    ./hyprland
    ./nushell
    ./wezterm
    ./nvim
    ./starship
    ./vscode-custom
    ./yazi
    ./ashell
    ./bluetui
    ./impala
  ];
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.packages = with pkgs; [ hello ];
  programs.home-manager.enable = true;
}
