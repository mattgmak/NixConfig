''
  hl.config({
    gestures = {
      workspace_swipe_touch = true,
      workspace_swipe_cancel_ratio = 0.15,
    },
    plugin = {
      hyprgrass = {
        sensitivity = 4.0,
        long_press_delay = 400,
        resize_on_border_long_press = true,
        edge_margin = 10,
      },
    },
  })

  hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "up" },
    action = "fullscreen",
  })
  hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 3, direction = "down" },
    action = "float",
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "swipe", fingers = 3, direction = "ru" },
    action = hl.dsp.window.center(),
  })
  hl.plugin.hyprgrass.gesture({
    pattern = { kind = "swipe", fingers = 4, direction = "down" },
    action = "close",
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "swipe", fingers = 4, direction = "up" },
    action = hl.dsp.layout("cyclenext"),
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "swipe", fingers = 4, direction = "right" },
    action = hl.dsp.layout("cycleprev"),
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "tap", fingers = 3 },
    action = hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"),
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "tap", fingers = 4 },
    action = hl.dsp.exec_cmd("rofi -show drun"),
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "tap", fingers = 5 },
    action = hl.dsp.exec_cmd("~/.config/hypr/scripts/window-switcher.nu"),
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "longpress", fingers = 2 },
    action = hl.dsp.window.drag(),
    mouse = true,
  })
  hl.plugin.hyprgrass.bind({
    pattern = { kind = "longpress", fingers = 3 },
    action = hl.dsp.window.resize(),
    mouse = true,
  })
''
