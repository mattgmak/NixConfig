#! /usr/bin/env nu

let animation_enabled = hyprctl getoption animations:enabled | grep -o '[0-9]*$' | into bool

if $animation_enabled {
  hyprctl keyword animations:enabled 0
  notify-send "Animations disabled"
} else {
  hyprctl keyword animations:enabled 1
  notify-send "Animations enabled"
}
