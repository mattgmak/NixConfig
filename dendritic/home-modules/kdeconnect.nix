{
  flake.homeModules.kdeconnect = {
    # Stylix sets QT_QPA_PLATFORMTHEME=qt5ct, whose QFileDialog ignores
    # xdg-desktop-portal, so "Send files" opens Qt's own dialog instead of the
    # configured terminal picker. gtk3 + GTK_USE_PORTAL=1 routes that dialog to
    # the portal; scoped to KDE Connect so other Qt apps keep the qt5ct theme.
    systemd.user.services.kdeconnect-indicator.Service.Environment = [
      "QT_QPA_PLATFORMTHEME=gtk3"
      "GTK_USE_PORTAL=1"
    ];

    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
