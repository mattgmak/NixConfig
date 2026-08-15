hl.permission("/run/current-system/sw/bin/steam", "screencopy", "allow")
hl.permission("/run/current-system/sw/bin/steam", "cursorpos", "allow")
hl.permission("/run/current-system/sw/bin/steam", "keyboard", "allow")
hl.permission("/run/current-system/sw/bin/steam", "input-capture", "allow")

-- Hyprland plugins (nix store paths change per rebuild, so match by name)
hl.permission(".*/libcsgo-vulkan-fix\\.so", "plugin", "allow")
hl.permission(".*/libhyprgrass\\.so", "plugin", "allow")

-- quickshell (caelestia shell): needs capture/input for wallpaper, overview, overlays
hl.permission(".*/quickshell", "screencopy", "allow")
hl.permission(".*/quickshell", "cursorpos", "allow")
hl.permission(".*/quickshell", "keyboard", "allow")
hl.permission(".*/quickshell", "input-capture", "allow")
