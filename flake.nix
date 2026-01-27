{
  description = "NixOS config flake";

  inputs = {
    nixpkgs-stable = { url = "github:nixos/nixpkgs?ref=nixos-25.05"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-for-cursor = { url = "github:nixos/nixpkgs/master"; };
    nixpkgs-for-osu = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # url = "github:SoumyabrataBanik/flake-zen-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    xremap-flake.url = "github:xremap/nix-flake";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util.url = "github:hraban/mac-app-util";

    xdg-termfilepickers = {
      url = "github:Guekka/xdg-desktop-portal-termfilepickers";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sherlock = {
      url = "github:Skxxtz/sherlock";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    wiremix = {
      url = "github:tsowell/wiremix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

    # ghostty = { url = "github:ghostty-org/ghostty?ref=v1.1.3"; };
    ghostty = { url = "github:ghostty-org/ghostty"; };
  };

  outputs = { nixpkgs, nixpkgs-stable, nixpkgs-for-cursor, nixpkgs-for-osu
    , nix-darwin, ... }@inputs:
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
      pkgs-for-cursor-darwin = import nixpkgs-for-cursor {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };
      pkgs-for-osu = import nixpkgs-for-osu {
        inherit system;
        config.allowUnfree = true;
      };
      laptopName = "GoofyEnvy";
      wslName = "GoofyWSL";
      vmName = "GoofyVM";
      macMiniName = "MacMini";
      desktopName = "GoofyDesky";
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
      darwinConfigurations.${macMiniName} = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs pkgs-stable;
          pkgs-for-cursor = pkgs-for-cursor-darwin;
          username = "mattgmak";
          hostname = macMiniName;
        };
        modules = [ ./hosts/${macMiniName} ];
      };
      nixosConfigurations.${desktopName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username pkgs-stable pkgs-for-cursor pkgs-for-osu
            system;
          hostname = desktopName;
        };
        modules = [ ./hosts/${desktopName} ];
      };
    };
}
