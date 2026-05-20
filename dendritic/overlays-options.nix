{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (flake-parts-lib) mkTransposedPerSystemModule;
  inherit (lib) mkOption types;
in
{
  imports = [
    (mkTransposedPerSystemModule {
      name = "common-overlays";
      file = ./overlays.nix;
      option = mkOption {
        description = "Shared nixpkgs overlays; each host assigns nixpkgs.overlays explicitly.";
        type = types.listOf types.unspecified;
        default = [ ];
      };
    })
    (mkTransposedPerSystemModule {
      name = "common-nixpkgs-config";
      file = ./overlays.nix;
      option = mkOption {
        description = "Shared nixpkgs.config defaults (allowUnfree, permittedInsecurePackages, …).";
        type = types.attrsOf types.unspecified;
        default = { };
      };
    })
  ];
}
