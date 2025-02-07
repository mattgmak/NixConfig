{ pkgs, ... }:
let
in {
  # programs.eww = {
  #   enable = true;
  #   package = pkgs.eww;
  #   configDir = ./config;
  # };
  home.file = {
    ".config/eww/" = {
      source = ./config;
      recursive = true;
    };
  };
}
