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
  };
}
