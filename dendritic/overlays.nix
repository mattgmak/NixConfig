{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (_: _: { ghostty = inputs.ghostty.packages.${system}.default; })
          inputs.nix4vscode.overlays.default
        ];
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "ventoy-1.1.07" ];
        };
      };
    };
}
