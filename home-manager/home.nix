{ hostname }: {
  imports = [
    ./terminal/nushell
    ./terminal/wezterm
    ./terminal/nvim
    ./terminal/starship
    ./terminal/yazi
    ./terminal/git
    ./terminal/direnv
    ./terminal/lazygit
  ] ++ (if hostname == "GoofyEnvy" then [
    ./terminal/bluetui
    ./desktop/onedrive
    ./desktop/vscode-custom
    ./desktop/hyprland
    ./desktop/waybar
    ./desktop/zen-browser
    ./desktop/wlogout
    ./desktop/rofi
    ./desktop/mako
    ./desktop/input-remapper
    ./desktop/fcitx5
    ./terminal/clipse
    ./desktop/mpv
    ./terminal/termfilechooser
  ] else if hostname == "GoofyWSL" then
    [

    ]
  else
    [ ]);
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
      "x-scheme-handler/http" = [ "zen.desktop" ];
      "x-scheme-handler/https" = [ "zen.desktop" ];
      "x-scheme-handler/chrome" = [ "zen.desktop" ];
      "application/x-extension-htm" = [ "zen.desktop" ];
      "application/x-extension-html" = [ "zen.desktop" ];
      "application/x-extension-shtml" = [ "zen.desktop" ];
      "application/xhtml+xml" = [ "zen.desktop" ];
      "application/x-extension-xhtml" = [ "zen.desktop" ];
      "application/x-extension-xht" = [ "zen.desktop" ];
    };
  };
  programs.home-manager.enable = true;
}
