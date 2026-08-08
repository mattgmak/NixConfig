''
  hl.curve("myBezier", { type = "bezier", points = { {0.10, 0.9}, {0.1, 1.05} } })

  hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "myBezier" })
  hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "myBezier" })
  hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
  hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
  hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "default" })

  hl.gesture({ fingers = 3, direction = "horizontal", scale = 0.5, action = "workspace" })
  hl.gesture({ fingers = 3, direction = "vertical", scale = 0.5, action = "fullscreen" })
''
