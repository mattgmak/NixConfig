{
  description = "Dev shells";
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; }; };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.drpom = pkgs.mkShell {
        packages = with pkgs;
          [ nodejs_20 androidenv.androidPkgs.platform-tools chromium deno ]
          ++ (with pkgs.nodePackages; [ firebase-tools ]);
        shellHook = ''
          cd ~/DrPOM
          nu
        '';
      };
    };
}
