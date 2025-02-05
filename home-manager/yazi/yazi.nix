{ ... }:
let
  keymapTomlText = builtins.readFile ./keymap.toml;
  themeTomlText = builtins.readFile ./theme.toml;
  settingsTomlText = builtins.readFile ./yazi.toml;
in {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    init = ./init.lua;
    keymap = keymapTomlText;
    theme = themeTomlText;
    settings = settingsTomlText;
  };
  home.file = {

  };
}
