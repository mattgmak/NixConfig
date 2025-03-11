{
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
    ./rofi
    ./mako
    ./input-remapper
    ./fcitx5
    ./clipse
    ./onedrive
    ./termfilechooser
    ./zen-browser
    ./git
    ./wlogout
    ./direnv
    ./lazygit
  ];
  home = {
    username = "goofy";
    homeDirectory = "/home/goofy";
    stateVersion = "24.11"; # Please read the comment before changing.
  };
  programs.home-manager.enable = true;
}
