{ ... }:
let
in {
  home.file = {
    ".config/wezterm".source = ./config;
    recursive = true;
  };
}
