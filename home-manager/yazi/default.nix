{ pkgs, inputs, lib, ... }:
let
  keymapTomlText = builtins.fromTOML (builtins.readFile ./keymap.toml);
  settingsTomlText = builtins.fromTOML (builtins.readFile ./yazi.toml);
  glow-plugin = pkgs.callPackage ./glow-plugin.nix { };
  starship-plugin = pkgs.callPackage ./starship-plugin.nix { };
in {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    initLua = ./init.lua;
    keymap = keymapTomlText;
    settings = settingsTomlText;
    # yaziPlugins = { starship.enable = true; };
    plugins = with pkgs.yaziPlugins; [ starship ];
  };

  home.packages = with pkgs; [ glow starship ];

  home.file.".config/yazi/plugins/glow".source =
    "${glow-plugin}/share/yazi/plugins/glow";
  home.file.".config/yazi/plugins/starship".source =
    "${starship-plugin}/share/yazi/plugins/starship";

  home.file = {

  };
}
