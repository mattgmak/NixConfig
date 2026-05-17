{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (_: _: { ghostty = inputs.ghostty.packages.${system}.default; })
          (_final: super: {
            direnv = super.direnv.overrideAttrs (_: {
              doCheck = false;
            });
          })
          inputs.nix4vscode.overlays.default
          inputs.coding-agents.overlays.default
        ];
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "ventoy-1.1.07" ];
        };
      };
    };
}
