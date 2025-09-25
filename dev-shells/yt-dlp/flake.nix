{
  description = "yt-dlp dev shell";
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; }; };

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: pkgs:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in {
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system nixpkgs;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ python313Packages.mutagen ];
          };
        });
    };
}
