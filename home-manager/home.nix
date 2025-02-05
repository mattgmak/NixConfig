{ config, pkgs, ... }: {
  imports = [
    ./hyprland.nix
    ./nushell/nushell.nix
    ./wezterm/wezterm.nix
    ./nvim/nvim.nix
    ./starship/starship.nix
    ./vscode-custom/vscode-custom.nix
    ./yazi/yazi.nix
    ./ashell/ashell.nix
  ];
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.packages = with pkgs; [ hello ];
  programs.home-manager.enable = true;
}
