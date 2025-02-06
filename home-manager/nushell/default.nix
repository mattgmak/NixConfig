{ ... }:
let
  # startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
  #   ${pkgs.waybar}/bin/waybar &
  #   clipse -listen &
  # '';
in {
  home.file = {
    ".config/nushell/config.nu".source = ./config.nu;
    ".config/nushell/env.nu".source = ./env.nu;
    ".config/nushell/scripts/conda.nu".source = ./scripts/conda.nu;
  };
}
