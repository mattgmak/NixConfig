{ config, pkgs, ... }: {
  imports = [ ./hyprland.nix ./nushell.nix ];
  home.username = "goofy";
  home.homeDirectory = "/home/goofy";
  home.stateVersion = "24.11"; # Please read the comment before changing.
  home.packages = with pkgs; [ hello ];
  programs.home-manager.enable = true;
}
