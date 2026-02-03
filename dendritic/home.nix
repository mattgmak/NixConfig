{ inputs, self, ... }:
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];
  flake = {
    homeModules.main =
      {
        hostname,
        username,
        pkgs,
        ...
      }:
      {
        imports = [
          self.homeModules.nushell
          self.homeModules.wezterm
          self.homeModules.neovim
          self.homeModules.starship
          self.homeModules.yazi
          self.homeModules.git
          self.homeModules.direnv
          self.homeModules.lazygit
          self.homeModules.ghostty
          self.homeModules.cursor
        ]
        ++ (
          if (hostname == "GoofyEnvy" || hostname == "GoofyDesky") then
            [
              self.homeModules.bluetui
              self.homeModules.hyprland
              # self.homeModules.waybar
              self.homeModules.wlogout
              self.homeModules.fcitx5
              self.homeModules.mpv
              self.homeModules.kdeconnect
              self.homeModules.filepicker
              self.homeModules.wiremix
              self.homeModules.caelestia
            ]
          else
            [ ]
        );
        home = {
          username = username;
          homeDirectory = if hostname == "MacMini" then "/Users/${username}" else "/home/${username}";
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
      };
  }

  ;
}
