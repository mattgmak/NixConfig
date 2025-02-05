{ config, pkgs, ... }:
let
  # startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
  #   ${pkgs.waybar}/bin/waybar &
  #   clipse -listen &
  # '';
in {
  programs.nushell = {
    enable = true;
    # configFile.source = ./config.nu;
    # envFile.source = ./env.nu;
  };
  home.file = {
    ".config/nushell/config.nu".source = ./config.nu;
    ".config/nushell/env.nu".source = ./env.nu;
    ".config/nushell/scripts/conda.nu".source = ./scripts/conda.nu;
  };
}
