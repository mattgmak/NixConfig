{ ... }:
let
in {
  home.file = {
    ".config/nvim" = {
      source = ./config;
      recursive = true;
    };
  };
}
