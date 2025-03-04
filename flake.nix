{
  description = "Nixos config flake";

  inputs = {
    nixpkgs-stable = { url = "github:nixos/nixpkgs?ref=nixos-24.11"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
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

  outputs = { nixpkgs, nixpkgs-stable, home-manager, stylix, ... }@inputs:
    let
      username = "goofy";
      hostname = "GoofyEnvy";
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations."${hostname}" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username pkgs pkgs-stable; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              backupFileExtension = "hm-backup";
              users.goofy = import ./home-manager/home.nix;
            };
          }
          stylix.nixosModules.stylix
        ];
      };
      devShells.${system}.drpom = pkgs.mkShell {
        packages = with pkgs;
          [ nodejs_20 androidenv.androidPkgs.platform-tools chromium deno ]
          ++ (with pkgs.nodePackages; [ firebase-tools ]);
        # shellHook = ''
        #   nu
        # '';
      };
    };
}
