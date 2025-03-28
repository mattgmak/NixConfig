#!/usr/bin/env bash
notify-send --urgency=LOW "Battery Notification" "Starting..."
while true; do
  bat_lvl=$(cat /sys/class/power_supply/BAT1/capacity)
  if [ "$bat_lvl" -le 15 ]; then
    notify-send --urgency=CRITICAL "Battery Low" "Level: ${bat_lvl}%"
    sleep 1200
  elif [ "$bat_lvl" -gt 90 ]; then
    notify-send --urgency=LOW "Battery Charged" "Level: ${bat_lvl}%"
    sleep 1200
  else
    sleep 120
  fi
done
