{
  description = "Nixos config flake";

  inputs = {
    # nixpkgs = { url = "github:nixos/nixpkgs?ref=nixos-24.11"; };
    # nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.nixpkgs.follows = "hyprland";
    };
    hyprpanel = {
      url = "github:jas-singhfsu/hyprpanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xremap-flake.url = "github:xremap/nix-flake";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins?ref=yazi-v0.2.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, stylix, ... }@inputs:
    let
      username = "goofy";
      hostname = "GoofyNixie";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations."${hostname}" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.default
          stylix.nixosModules.stylix
        ];
      };
      devShells.${system}.drpom = pkgs.mkShell {
        packages = with pkgs;
          [ nodejs_20 androidenv.androidPkgs.platform-tools chromium deno ]
          ++ (with pkgs.nodePackages; [ eas-cli firebase-tools ]);
        shellHook = ''
          cd ~/DrPOM
          nu
        '';
      };
    };
}
