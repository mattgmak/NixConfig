{ ... }:
let
in {
  programs.wezterm = { enable = true; };
  home.file.".config/wezterm" = {
    source = ./config;
    recursive = true;
  };
}
