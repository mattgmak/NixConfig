{ pkgs, inputs, lib, ... }:
let
  keymapTomlText = builtins.fromTOML (builtins.readFile ./keymap.toml);
  settingsTomlText = builtins.fromTOML (builtins.readFile ./yazi.toml);
  plugins = [
    {
      name = "glow";
      pkg = pkgs.callPackage ./plugins/glow.nix { };
    }
    {
      name = "starship";
      pkg = pkgs.callPackage ./plugins/starship.nix { };
    }
    {
      name = "relative-motions";
      pkg = pkgs.callPackage ./plugins/relative-motions.nix { };
    }
  ];
in {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    initLua = ./init.lua;
    keymap = keymapTomlText;
    settings = settingsTomlText;
  };

  home.file = let
    basePluginPath = ".config/yazi/plugins";
    baseOutputPath = "share/yazi/plugins";
  in builtins.listToAttrs (map (plugin: {
    name = "${basePluginPath}/${plugin.name}.yazi";
    value = { source = "${plugin.pkg}/${baseOutputPath}/${plugin.name}"; };
  }) plugins);
}
