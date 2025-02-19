{ pkgs, inputs, lib, ... }:
let
  keymapTomlText = builtins.fromTOML (builtins.readFile ./keymap.toml);
  settingsTomlText = builtins.fromTOML (builtins.readFile ./yazi.toml);
  glow-plugin = pkgs.callPackage ./plugins/glow-plugin.nix { };
  starship-plugin = pkgs.callPackage ./plugins/starship-plugin.nix { };
  relative-motions-plugin =
    pkgs.callPackage ./plugins/relative-motions-plugin.nix { };
in {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    initLua = ./init.lua;
    keymap = keymapTomlText;
    settings = settingsTomlText;
    # yaziPlugins = { starship.enable = true; };
    # plugins = with pkgs.yaziPlugins; [ starship ];
  };

  # home.packages = with pkgs; [ glow starship ];

  # home.file.".config/yazi/plugins/glow.yazi".source =
  #   "${glow-plugin}/share/yazi/plugins/glow";
  # home.file.".config/yazi/plugins/starship.yazi".source =
  #   "${starship-plugin}/share/yazi/plugins/starship";
  # home.file.".config/yazi/plugins/relative-motions.yazi".source =
  #   "${relative-motions-plugin}/share/yazi/plugins/relative-motions";

  home.file = let basePath = ".config/yazi/plugins"; in {
    "${basePath}/glow.yazi".source = "${glow-plugin}/share/yazi/plugins/glow";
    "${basePath}/starship.yazi".source = "${starship-plugin}/share/yazi/plugins/starship";
    "${basePath}/relative-motions.yazi".source = "${relative-motions-plugin}/share/yazi/plugins/relative-motions";
  };
  }
