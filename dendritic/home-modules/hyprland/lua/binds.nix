{
  hostname,
  lib,
  woomerLaunch,
}:
let
  allWorkspacesIndex = lib.map (i: toString i) (lib.range 1 10);

  bind =
    key: action: opts:
    let
      optsStr =
        if opts == null || opts == { } then
          ""
        else
          ", { "
          + lib.concatStringsSep ", " (
            lib.mapAttrsToList (
              k: v: if lib.isBool v then "${k} = ${if v then "true" else "false"}" else "${k} = ${v}"
            ) opts
          )
          + " }";
    in
    "hl.bind(\"${key}\", ${action}${optsStr})";

  workspaceBinds = lib.concatMap (
    index:
    let
      key = if index == "10" then "0" else index;
    in
    [
      (bind "ALT + ${key}" "hl.dsp.focus({ workspace = \"${index}\" })" null)
      (bind "ALT + SHIFT + ${key}" "hl.dsp.window.move({ workspace = \"${index}\", silent = true })" null)
    ]
  ) allWorkspacesIndex;

  binds = [
    (bind "ALT + m" "hl.dsp.exec_cmd(\"caelestia shell drawers toggle launcher\")" null)
    (bind "ALT + SHIFT + m" "hl.dsp.exec_cmd(\"rofi -show drun\")" null)
    (bind "ALT + h" "hl.dsp.focus({ direction = \"left\" })" null)
    (bind "ALT + j" "hl.dsp.focus({ direction = \"down\" })" null)
    (bind "ALT + k" "hl.dsp.focus({ direction = \"up\" })" null)
    (bind "ALT + l" "hl.dsp.focus({ direction = \"right\" })" null)
    (bind "ALT + Up" "hl.dsp.focus({ direction = \"up\" })" null)
    (bind "ALT + Down" "hl.dsp.focus({ direction = \"down\" })" null)
    (bind "ALT + SUPER + Up" "hl.dsp.layout(\"move +col\")" null)
    (bind "ALT + SUPER + Down" "hl.dsp.layout(\"move -col\")" null)
    (bind "ALT + mouse_up" "hl.dsp.layout(\"move +col\")" null)
    (bind "ALT + mouse_down" "hl.dsp.layout(\"move -col\")" null)
    (bind "ALT + Left" "hl.dsp.focus({ direction = \"left\" })" null)
    (bind "ALT + Right" "hl.dsp.focus({ direction = \"right\" })" null)
    (bind "ALT + SHIFT + h" "hl.dsp.window.move({ direction = \"left\" })" null)
    (bind "ALT + SHIFT + j" "hl.dsp.window.move({ direction = \"down\" })" null)
    (bind "ALT + SHIFT + k" "hl.dsp.window.move({ direction = \"up\" })" null)
    (bind "ALT + SHIFT + l" "hl.dsp.window.move({ direction = \"right\" })" null)
    (bind "ALT + SHIFT + Left" "hl.dsp.window.move({ direction = \"left\" })" null)
    (bind "ALT + SHIFT + Down" "hl.dsp.window.move({ direction = \"down\" })" null)
    (bind "ALT + SHIFT + Up" "hl.dsp.window.move({ direction = \"up\" })" null)
    (bind "ALT + SHIFT + Right" "hl.dsp.window.move({ direction = \"right\" })" null)
    (bind "ALT + Tab" "hl.dsp.layout(\"cyclenext\")" null)
    (bind "ALT + SHIFT + Tab" "hl.dsp.layout(\"cycleprev\")" null)
    (bind "ALT + t" "hl.dsp.window.float({ action = \"toggle\" })" null)
    (bind "ALT + f" "hl.dsp.window.fullscreen()" null)
    (bind "ALT + d" "hl.dsp.window.kill()" null)
    (bind "ALT + c" "hl.dsp.window.center()" null)
    (bind "ALT + G" "hl.dsp.focus({ workspace = \"name:Game\" })" null)
    (bind "ALT + SHIFT + G" "hl.dsp.window.move({ workspace = \"name:Game\", silent = true })" null)
    (bind "XF86AudioMute" "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")" null)
    (bind "XF86AudioMicMute" "hl.dsp.exec_cmd(\"~/.config/hypr/scripts/mic-toggle.sh\")" null)
    (bind "ALT + SHIFT + M" "hl.dsp.exec_cmd(\"caelestia shell --kill; caelestia shell -d\")" null)
    (bind "SUPER + V" "hl.dsp.exec_cmd(\"ghostty --title=clipse -e clipse\")" null)
    (bind "SUPER + B" "hl.dsp.exec_cmd(\"ghostty --title=bluetui -e bluetui\")" null)
    (bind "SUPER + Q" "hl.dsp.exec_cmd(\"ghostty --title=btop -e btop\")" null)
    (bind "SUPER + A" "hl.dsp.exec_cmd(\"ghostty --title=wiremix -e wiremix\")" null)
    (bind "SUPER + M" "hl.dsp.exec_cmd(\"ghostty --title=nmtui -e nmtui\")" null)
    (bind "SUPER + SHIFT + S" "hl.dsp.global(\"caelestia:screenshotFreeze\")" null)
    (bind "SUPER + SHIFT + C" "hl.dsp.exec_cmd(\"hyprpicker -a\")" null)
    (bind "ALT + N" "hl.dsp.global(\"caelestia:clearNotifs\")" null)
    (bind "ALT + B" "hl.dsp.exec_cmd(\"caelestia shell drawers toggle sidebar\")" null)
    (bind "SUPER + R" "hl.dsp.exec_cmd(\"zen-beta\")" null)
    (bind "SUPER + E" "hl.dsp.exec_cmd(\"cursor\")" null)
    (bind "SUPER + W" "hl.dsp.exec_cmd(\"ghostty\")" null)
    (bind "ALT + Z" "hl.dsp.exec_cmd(\"${woomerLaunch}\")" null)
    (bind "SUPER + F" "hl.dsp.exec_cmd(\"hyprctl hyprsunset temperature 4500\")" null)
    (bind "SUPER + G" "hl.dsp.exec_cmd(\"~/.config/hypr/scripts/animation-toggle.nu\")" null)
    (bind "SUPER + SPACE" "hl.dsp.exec_cmd(\"fcitx5-remote -t\")" null)
    (bind "SUPER + period" "hl.dsp.exec_cmd(\"true\")" null)
    (bind "ALT + Q" "hl.dsp.exec_cmd(\"wlogout\")" null)
    (bind "SUPER + T" "hl.dsp.exec_cmd(\"~/.config/hypr/scripts/floating-terminal.nu\")" null)
    (bind "ALT + Comma" "hl.dsp.exec_cmd(\"~/.config/hypr/scripts/window-switcher.nu\")" null)
  ]
  ++ workspaceBinds
  ++ [
    (bind "ALT + SHIFT + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
    (bind "ALT + mouse:272" "hl.dsp.window.resize()" { mouse = true; })
    (bind "ALT + i" "hl.dsp.window.resize({ x = 0, y = -20, relative = true })" { repeating = true; })
    (bind "ALT + u" "hl.dsp.window.resize({ x = 0, y = 20, relative = true })" { repeating = true; })
    (bind "ALT + y" "hl.dsp.window.resize({ x = -20, y = 0, relative = true })" { repeating = true; })
    (bind "ALT + o" "hl.dsp.window.resize({ x = 20, y = 0, relative = true })" { repeating = true; })
    (bind "ALT + SHIFT + i" "hl.dsp.window.move({ x = 0, y = -20, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + u" "hl.dsp.window.move({ x = 0, y = 20, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + y" "hl.dsp.window.move({ x = -20, y = 0, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + o" "hl.dsp.window.move({ x = 20, y = 0, relative = true })" {
      repeating = true;
    })
    (bind "ALT + Prior" "hl.dsp.window.resize({ x = 0, y = -20, relative = true })" {
      repeating = true;
    })
    (bind "ALT + Next" "hl.dsp.window.resize({ x = 0, y = 20, relative = true })" { repeating = true; })
    (bind "ALT + Home" "hl.dsp.window.resize({ x = -20, y = 0, relative = true })" {
      repeating = true;
    })
    (bind "ALT + End" "hl.dsp.window.resize({ x = 20, y = 0, relative = true })" { repeating = true; })
    (bind "ALT + SHIFT + Prior" "hl.dsp.window.move({ x = 0, y = -20, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + Next" "hl.dsp.window.move({ x = 0, y = 20, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + Home" "hl.dsp.window.move({ x = -20, y = 0, relative = true })" {
      repeating = true;
    })
    (bind "ALT + SHIFT + End" "hl.dsp.window.move({ x = 20, y = 0, relative = true })" {
      repeating = true;
    })
    (bind "XF86AudioRaiseVolume" "hl.dsp.exec_cmd(\"wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%+\")"
      {
        repeating = true;
      }
    )
    (bind "XF86AudioLowerVolume" "hl.dsp.exec_cmd(\"wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%-\")"
      {
        repeating = true;
      }
    )
    (bind "XF86MonBrightnessUp" "hl.dsp.global(\"caelestia:brightnessUp\")" { locked = true; })
    (bind "XF86MonBrightnessDown" "hl.dsp.global(\"caelestia:brightnessDown\")" { locked = true; })
    (bind "XF86AudioPlay" "hl.dsp.global(\"caelestia:mediaToggle\")" { locked = true; })
    (bind "XF86AudioPause" "hl.dsp.global(\"caelestia:mediaToggle\")" { locked = true; })
    (bind "XF86AudioNext" "hl.dsp.global(\"caelestia:mediaNext\")" { locked = true; })
    (bind "XF86AudioPrev" "hl.dsp.global(\"caelestia:mediaPrev\")" { locked = true; })
    (bind "ALT + R" "hl.dsp.focus({ window = \"initialtitle:(Zen Browser)\" })" {
      locked = true;
      repeating = true;
    })
    (bind "ALT + E" "hl.dsp.focus({ window = \"class:(.*[Cc]ursor.*)\" })" {
      locked = true;
      repeating = true;
    })
    (bind "ALT + W" "hl.dsp.focus({ window = \"class:(.*ghostty.*)\" })" {
      locked = true;
      repeating = true;
    })
    (bind "ALT + O" "hl.dsp.focus({ window = \"class:(OrcaSlicer)\" })" {
      locked = true;
      repeating = true;
    })
  ];
in
lib.concatStringsSep "\n" binds
