#!/usr/bin/env bash

# Power menu script for Waybar using rofi with snowflake theme

# Define the options with their icons
options=(
  "❄️ Sleep"
  "❄️ Power Off"
  "❄️ Restart"
)

# Show rofi menu with custom theme
selected=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "Power Menu" \
  -theme-str 'window {width: 250px; border-radius: 5px;}' \
  -theme-str 'element-icon {size: 18px;}' \
  -theme-str 'element {padding: 4px;}')

# Handle the selection
case "$selected" in
"❄️ Sleep")
  exec systemctl suspend
  ;;
"❄️ Power Off")
  exec systemctl poweroff
  ;;
"❄️ Restart")
  exec systemctl reboot
  ;;
esac
