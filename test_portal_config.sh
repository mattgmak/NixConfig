#!/usr/bin/env bash

# Print environment variables related to portals
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-Not set}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-Not set}"

# Check if the portal configuration files exist
echo "Checking portal configuration files..."
if [ -f ~/.config/xdg-desktop-portal/portals.conf ]; then
  echo "✅ Portal configuration file exists:"
  cat ~/.config/xdg-desktop-portal/portals.conf
else
  echo "❌ Portal configuration file does not exist"
fi

if [ -f ~/.config/xdg-desktop-portal/hyprland-portals.conf ]; then
  echo "✅ Hyprland-specific portal configuration file exists:"
  cat ~/.config/xdg-desktop-portal/hyprland-portals.conf
else
  echo "❌ Hyprland-specific portal configuration file does not exist"
fi

# Check if termfilechooser is running
if busctl --user list | grep -q termfilechooser; then
  echo "✅ termfilechooser service is running"
else
  echo "❌ termfilechooser service is NOT running"
fi

# Check if the main portal service is running
if systemctl --user is-active xdg-desktop-portal.service >/dev/null; then
  echo "✅ xdg-desktop-portal service is active"
else
  echo "❌ xdg-desktop-portal service is NOT active"
fi

# Check if the FileChooser interface is available in the main portal
echo "Checking if FileChooser interface is available in the main portal..."
if busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.DBus.Introspectable Introspect | grep -q "org.freedesktop.portal.FileChooser"; then
  echo "✅ FileChooser interface is available in the main portal"
else
  echo "❌ FileChooser interface is NOT available in the main portal"
  echo "You may need to restart the portal services:"
  echo "systemctl --user restart xdg-desktop-portal.service"
fi

echo ""
echo "If the configuration is not working, try the following steps:"
echo "1. Rebuild your home-manager configuration:"
echo "   home-manager switch"
echo "2. Restart the portal services:"
echo "   systemctl --user restart xdg-desktop-portal.service"
echo "3. Log out and log back in to ensure all environment variables are set correctly"
