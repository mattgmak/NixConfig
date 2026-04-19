{ inputs, withSystem, ... }:
{
  perSystem =
    { system, ... }:
    {
      legacyPackages =
        let
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-for-cursor = import inputs.nixpkgs-for-cursor {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-unstable = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-for-homelab = import inputs.nixpkgs-for-homelab {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.copyparty.overlays.default ];
          };
          pkgs-for-vr = import inputs.nixpkgs-for-vr {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          inherit
            pkgs-stable
            pkgs-for-cursor
            pkgs-unstable
            pkgs-for-homelab
            pkgs-for-vr
            ;
        };
    };
  flake.nixpkgsConfig =
    { config, ... }:
    {
      nixpkgs.pkgs = withSystem config.nixpkgs.hostPlatform.system ({ pkgs, ... }: pkgs);
    };
}
