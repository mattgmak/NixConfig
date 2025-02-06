{ ... }:
let
  keymapTomlText = builtins.fromTOML (builtins.readFile ./keymap.toml);
  themeTomlText = builtins.fromTOML (builtins.readFile ./theme.toml);
  settingsTomlText = builtins.fromTOML (builtins.readFile ./yazi.toml);
in {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    initLua = ./init.lua;
    keymap = keymapTomlText;
    theme = themeTomlText;
    settings = settingsTomlText;
  };
  home.file = {

  };
}
