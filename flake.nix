{
  description = "Nixos config flake";

  inputs = {
    nixpkgs-stable = { url = "github:nixos/nixpkgs?ref=nixos-24.11"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-for-cursor = { url = "github:nixos/nixpkgs/nixos-unstable"; };
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

    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, nixpkgs-stable, nixpkgs-for-cursor, ... }@inputs:
    let
      username = "goofy";
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-for-cursor = import nixpkgs-for-cursor {
        inherit system;
        config.allowUnfree = true;
      };
      laptopName = "GoofyEnvy";
      wslName = "GoofyWSL";
      vmName = "GoofyVM";
    in {
      nixosConfigurations.${laptopName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username pkgs-stable pkgs-for-cursor system;
          hostname = laptopName;
        };
        modules = [ ./hosts/${laptopName} ];
      };
      nixosConfigurations.${wslName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username pkgs-stable pkgs-for-cursor system;
          hostname = wslName;
        };
        modules = [ ./hosts/${wslName} ];
      };
      nixosConfigurations.${vmName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username pkgs-stable pkgs-for-cursor system;
          hostname = vmName;
        };
        modules = [ ./hosts/${vmName} ];
      };
    };
}
