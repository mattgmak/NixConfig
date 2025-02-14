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
    ./impala
    ./rofi
  ];
  home = {
    username = "goofy";
    homeDirectory = "/home/goofy";
    sessionVariables = {
      TERMINAL = "wezterm";
      BROWSER = "zen";
    };
    stateVersion = "24.11"; # Please read the comment before changing.
  };
  programs.home-manager.enable = true;
}
