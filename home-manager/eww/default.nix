{ pkgs, ... }:
let
in {
  programs.eww = {
    enable = true;
    package = pkgs.eww;
    configDir = ./config;
  };
  home.file = {
    ".config/eww-scripts" = {
      source = ./scripts;
      recursive = true;
    };
  };
}
