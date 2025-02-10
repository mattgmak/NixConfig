{ config, pkgs, ... }: {
  imports = [
    ./hyprland
    ./waybar
    ./nushell
    ./wezterm
    ./nvim
    ./starship
    ./vscode-custom
    ./yazi
    ./bluetui
    ./impala
    ./rofi
    # ./eww
    # ./hyprpanel
  ];
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.packages = with pkgs; [ hello ];
  programs.home-manager.enable = true;
}
