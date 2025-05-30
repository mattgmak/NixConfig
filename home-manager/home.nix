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
      "text/html" = [ "zen-beta.desktop" ];
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "x-scheme-handler/chrome" = [ "zen-beta.desktop" ];
      "application/x-extension-htm" = [ "zen-beta.desktop" ];
      "application/x-extension-html" = [ "zen-beta.desktop" ];
      "application/x-extension-shtml" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];
      "application/x-extension-xhtml" = [ "zen-beta.desktop" ];
      "application/x-extension-xht" = [ "zen-beta.desktop" ];
    };
  };
  programs.home-manager.enable = true;
}
