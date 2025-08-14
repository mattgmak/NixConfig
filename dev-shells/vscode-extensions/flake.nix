{
  description = "VSCode extensions dev shell";
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    biome-pin = {
      url = "github:nixos/nixpkgs/6b4955211758ba47fac850c040a27f23b9b4008f";
    };
  };

  outputs = { nixpkgs, biome-pin, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: pkgs:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
    in {
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system nixpkgs;
          biome-pin-pkgs = pkgsFor system biome-pin;
        in {
          default = pkgs.mkShell {
            NODE_OPTIONS = "--experimental-vm-modules";
            BIOME_BINARY = "${biome-pin-pkgs.biome}/bin/biome";
            packages = with pkgs;
              [ nodejs_20 pnpm biome-pin-pkgs.biome ]
              ++ (with pkgs.nodePackages; [ vsce ]);
          };
        });
    };
}
