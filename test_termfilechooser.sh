#!/usr/bin/env bash

# Print environment variables related to portals
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-Not set}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-Not set}"

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

# Check if termfilechooser is properly registered
echo "Checking termfilechooser registration..."
if busctl --user introspect org.freedesktop.impl.portal.desktop.termfilechooser /org/freedesktop/portal/desktop 2>/dev/null | grep -q FileChooser; then
  echo "✅ termfilechooser is properly registered with FileChooser interface"
else
  echo "❌ termfilechooser is NOT properly registered with FileChooser interface"
fi

# Check if the FileChooser interface is available in the main portal
echo "Checking if FileChooser interface is available in the main portal..."
if busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.DBus.Introspectable Introspect | grep -q "org.freedesktop.portal.FileChooser"; then
  echo "✅ FileChooser interface is available in the main portal"
else
  echo "❌ FileChooser interface is NOT available in the main portal"
  echo "This suggests that the portal configuration is not correctly set up."
  echo "You may need to check your portal configuration in /etc/xdg/xdg-desktop-portal/ or ~/.config/xdg-desktop-portal/"
fi

# Check portal configuration
echo "Checking portal configuration..."
if [ -f ~/.config/xdg-desktop-portal/portals.conf ]; then
  echo "User portal configuration found:"
  cat ~/.config/xdg-desktop-portal/portals.conf
elif [ -f /etc/xdg/xdg-desktop-portal/portals.conf ]; then
  echo "System portal configuration found:"
  cat /etc/xdg/xdg-desktop-portal/portals.conf
else
  echo "No portal configuration file found."
  echo "You may need to create one at ~/.config/xdg-desktop-portal/portals.conf"
  echo "Example content:"
  echo "[preferred]"
  echo "default=gtk"
  echo "org.freedesktop.impl.portal.FileChooser=termfilechooser"
fi

# Check if the portal is correctly configured in NixOS
echo "Checking NixOS configuration..."
if grep -q "termfilechooser" /home/goofy/NixConfig/configuration.nix; then
  echo "✅ termfilechooser is configured in NixOS configuration"
else
  echo "❌ termfilechooser is NOT configured in NixOS configuration"
fi

echo ""
echo "Recommendation:"
echo "If the termfilechooser portal is not working correctly, try the following:"
echo "1. Create a portal configuration file at ~/.config/xdg-desktop-portal/portals.conf with the following content:"
echo "[preferred]"
echo "default=gtk"
echo "org.freedesktop.impl.portal.FileChooser=termfilechooser"
echo ""
echo "2. Restart the portal services:"
echo "systemctl --user restart xdg-desktop-portal.service"
echo ""
echo "3. Make sure XDG_CURRENT_DESKTOP is set correctly in your environment"
echo "4. Check if the termfilechooser portal is running after restart"
