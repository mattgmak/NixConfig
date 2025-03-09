#!/usr/bin/env bash

# Print environment variables related to portals
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-Not set}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-Not set}"

# Check if termfilechooser is running
if busctl --user list | grep -q termfilechooser; then
  echo "termfilechooser service is running"
else
  echo "termfilechooser service is NOT running"
fi

# Check if the main portal service is running
if systemctl --user is-active xdg-desktop-portal.service >/dev/null; then
  echo "xdg-desktop-portal service is active"
else
  echo "xdg-desktop-portal service is NOT active"
fi

# List available portal interfaces
echo "Available portal interfaces:"
busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop | grep "interface" | awk '{print $2}'

# Test file chooser using zenity (a simple GUI dialog tool)
echo "Testing file chooser with zenity..."
selected_file=$(zenity --file-selection 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "Selected file: $selected_file"
else
  echo "File selection canceled or failed"
fi

# Test file chooser using xdg-open
echo "Testing file chooser with xdg-open..."
xdg-open . &

# Try to directly test the portal
echo "Attempting to directly test the portal..."
gdbus call --session \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.OpenURI.OpenDirectory \
  "" "/" {} \
  2>/dev/null || echo "OpenDirectory method not available"

# Check if termfilechooser is properly registered
echo "Checking termfilechooser registration..."
if busctl --user introspect org.freedesktop.impl.portal.desktop.termfilechooser /org/freedesktop/portal/desktop 2>/dev/null | grep -q FileChooser; then
  echo "termfilechooser is properly registered with FileChooser interface"
else
  echo "termfilechooser is NOT properly registered with FileChooser interface"
fi
