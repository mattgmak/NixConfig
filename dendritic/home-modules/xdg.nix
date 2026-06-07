{
  flake.homeModules.xdg = {
    xdg.mimeApps = {
      enable = true;
      # Check for desktop file:
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
  };
}
