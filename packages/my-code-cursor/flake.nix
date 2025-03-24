{
  description = "Cursor IDE with my customizations";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };

  outputs = { nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in { packages.x86_64-linux.default = pkgs.callPackage ./package.nix { }; };
}
