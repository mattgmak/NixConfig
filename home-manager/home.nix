{ hostname, username, pkgs, ... }: {
  imports = [
    ./terminal/nushell
    ./terminal/wezterm
    ./terminal/nvim
    ./terminal/starship
    ./terminal/yazi
    ./terminal/git
    ./terminal/direnv
    ./terminal/lazygit
    ./terminal/ghostty
  ] ++ (if (hostname == "GoofyEnvy" || hostname == "GoofyDesky") then [
    ./desktop/cursor
    ./terminal/bluetui
    ./desktop/onedrive
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
    ./desktop/kdeconnect
    ./terminal/filepicker
    ./desktop/sherlock
    ./terminal/wiremix
  ] else if hostname == "GoofyWSL" then
    [

    ]
  else
    [ ]);
  home = {
    username = username;
    homeDirectory = if hostname == "MacMini" then
      "/Users/${username}"
    else
      "/home/${username}";
    stateVersion = "24.11"; # Please read the comment before changing.
  };
  xdg.mimeApps = pkgs.lib.mkIf (!pkgs.stdenv.isDarwin) {
    enable = true;
    # Check for desktop file:
    # ls /run/current-system/sw/share/applications/
    # Check for mime types:
    # xdg-mime query filetype file.type
    defaultApplications = {
      "application/pdf" = [ "okularApplication_pdf.desktop" ];
      "text/html" = [ "zen-browser.desktop" ];
      "x-scheme-handler/http" = [ "zen-browser.desktop" ];
      "x-scheme-handler/https" = [ "zen-browser.desktop" ];
      "x-scheme-handler/chrome" = [ "zen-browser.desktop" ];
      "application/x-extension-htm" = [ "zen-browser.desktop" ];
      "application/x-extension-html" = [ "zen-browser.desktop" ];
      "application/x-extension-shtml" = [ "zen-browser.desktop" ];
      "application/xhtml+xml" = [ "zen-browser.desktop" ];
      "application/x-extension-xhtml" = [ "zen-browser.desktop" ];
      "application/x-extension-xht" = [ "zen-browser.desktop" ];
    };
  };

  programs.home-manager.enable = true;
}
