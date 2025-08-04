#! /usr/bin/env nu

let shell_config = $"($env.HOME)/.config/hypr/scripts/floating-terminal-config.nu"
ghostty --title=floating-terminal -e nu -e $"\"source ($shell_config)\""
