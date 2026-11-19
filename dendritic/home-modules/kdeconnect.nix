{
  flake.homeModules.kdeconnect = {
    # Stylix sets QT_QPA_PLATFORMTHEME=qt5ct, whose QFileDialog ignores
    # xdg-desktop-portal, so "Send files" opens Qt's own dialog instead of the
    # configured terminal picker. gtk3 crashed on the missing
    # org.gtk.Settings.FileChooser schema; the xdgdesktopportal theme routes
    # that dialog to the portal. Scoped to KDE Connect so other Qt apps keep
    # the qt5ct theme and its Papirus tray icon.
    systemd.user.services.kdeconnect-indicator.Service.Environment = [
      "QT_QPA_PLATFORMTHEME=xdgdesktopportal"
    ];

    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
