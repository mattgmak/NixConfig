{
  description = "COMP3259 dev shell";
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; }; };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs.haskell.packages.ghc966; [
          Cabal
          ghc
          ghcid
          ormolu
          stack
          hlint
          hoogle
          haskell-language-server
          retrie
          pkgs.zlib
        ];
      };
    };
}
