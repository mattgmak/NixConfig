{
  home.file.".config/xdg-desktop-portal/portals.conf" = {
    text = ''
      [preferred]
      default=gtk
      org.freedesktop.impl.portal.FileChooser=termfilechooser
    '';
  };

  # Create a Hyprland-specific portal configuration
  home.file.".config/xdg-desktop-portal/hyprland-portals.conf" = {
    text = ''
      [preferred]
      default=gtk
      org.freedesktop.impl.portal.FileChooser=termfilechooser
    '';
  };
}
