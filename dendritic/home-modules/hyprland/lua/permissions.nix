# Hyprland permission rules (hl.permission). Hyprland matches with RE2
# FullMatch against the requesting app's FULL binary path, so store-path
# regexes use `.*/` instead of exact /nix/store paths (they change per rebuild).
''
  hl.permission("/run/current-system/sw/bin/steam", "screencopy", "allow")
  hl.permission("/run/current-system/sw/bin/steam", "cursorpos", "allow")
  hl.permission("/run/current-system/sw/bin/steam", "keyboard", "allow")
  hl.permission("/run/current-system/sw/bin/steam", "input-capture", "allow")

  -- Hyprland plugins (nix store paths change per rebuild, so match by name)
  hl.permission(".*/libcsgo-vulkan-fix\\.so", "plugin", "allow")
  hl.permission(".*/libhyprgrass\\.so", "plugin", "allow")

  -- quickshell (caelestia shell): needs capture/input for wallpaper, overview, overlays.
  -- Nix wraps quickshell, so the real binary is .quickshell-wrapped; match both names.
  hl.permission(".*/quickshell", "screencopy", "allow")
  hl.permission(".*/quickshell", "cursorpos", "allow")
  hl.permission(".*/quickshell", "keyboard", "allow")
  hl.permission(".*/quickshell", "input-capture", "allow")
  hl.permission(".*/\\.quickshell-wrapped", "screencopy", "allow")
  hl.permission(".*/\\.quickshell-wrapped", "cursorpos", "allow")
  hl.permission(".*/\\.quickshell-wrapped", "keyboard", "allow")
  hl.permission(".*/\\.quickshell-wrapped", "input-capture", "allow")
''
