#!/usr/bin/env bash
notify-send --urgency=LOW -t 10000 "Battery Notification" "Started"
while true; do
  bat_lvl=$(cat /sys/class/power_supply/BAT1/capacity)
  bat_status=$(cat /sys/class/power_supply/BAT1/status)
  if [ "$bat_lvl" -le 15 ] && [ "$bat_status" = "Discharging" ]; then
    notify-send --urgency=CRITICAL "Battery Low" "Level: ${bat_lvl}%"
    sleep 1200
  elif [ "$bat_lvl" -lt 30 ] && [ "$bat_status" = "Discharging" ]; then
    notify-send --urgency=NORMAL "Battery Warning" "Level: ${bat_lvl}%"
    sleep 600
  elif [ "$bat_lvl" -gt 90 ] && [ "$bat_status" = "Charging" ]; then
    notify-send --urgency=LOW "Battery Charged" "Level: ${bat_lvl}%"
    sleep 1200
  else
    sleep 120
  fi
done
