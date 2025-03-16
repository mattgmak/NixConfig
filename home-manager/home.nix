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
  xdg.mimeApps = {
    enable = true;
    # Check for desktop files:
    # ls /run/current-system/sw/share/applications/
    # Check for mime types:
    # xdg-mime query filetype file.type
    defaultApplications = {
      "application/pdf" = [ "okularApplication_pdf.desktop" ];
      "text/html" = [ "zen.desktop" ];
    };
  };
  programs.home-manager.enable = true;
}
