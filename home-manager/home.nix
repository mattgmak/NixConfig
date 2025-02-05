{ config, pkgs, ... }: {
  imports = [
    ./hyprland.nix
    ./nushell/nushell.nix
    ./wezterm/wezterm.nix
    ./nvim/nvim.nix
    ./starship/starship.nix
    ./vscode-custom/vscode-custom.nix
  ];
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.
  home.backupFileExtension = "hm-backup";
  # home.packages = with pkgs; [ hello ];
  programs.home-manager.enable = true;
}
