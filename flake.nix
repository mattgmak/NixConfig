{
  description = "NixOS config flake";
  inputs = {
    self.submodules = true;
    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    multiverse = {
      url = "github:fzakaria/nixpkgs-multiverse";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # url = "github:SoumyabrataBanik/flake-zen-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    hyprland.url = "github:hyprwm/Hyprland?ref=v0.56.2";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins?rev=81516add9b432b6ffc9f0906b92c9302c479c236";
      inputs.hyprland.follows = "hyprland";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass?ref=hl-0.56.1";
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
      url = "github:caelestia-dots/shell/v2.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

    ghostty = {
      url = "github:ghostty-org/ghostty?ref=v1.3.1";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

    yazi.url = "github:sxyazi/yazi/v26.5.6";

    nix-on-droid = {
      # url = "github:nix-community/nix-on-droid/release-24.05";
      url = "github:nix-community/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    worktrunk = {
      url = "github:max-sixty/worktrunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    whisper-dictation = {
      url = "git+file:./vendor/whisper-dictation";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    woomer = {
      url = "path:./vendor/woomer";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tree-sitter flake removed — neovim uses pkgs.tree-sitter (nixpkgs, hydra-cached)

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    coding-agents = {
      url = "github:kissgyorgy/coding-agents";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codegraph = {
      url = "github:mattgmak/codegraph/implement-nix-flake-support";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-sesh = {
      url = "git+file:./vendor/agent-sesh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    trek-src = {
      url = "github:mauriceboe/TREK/e65acb3de765f3c958dd4e139064b11fbbde79d1";
      flake = false;
    };

    # code-cursor-flake = {
    #   url = "github:jacopone/code-cursor-nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      import-tree,
      flake-parts,
      nix-on-droid,
      ...
    }@inputs:
    let
      lib = inputs.nixpkgs.lib;
      flake = flake-parts.lib.mkFlake { inherit inputs; } (
        (import-tree.filterNot (path: lib.hasInfix "/vendor/" path || lib.hasInfix "/hyprland/lua/" path))
          ./dendritic
      );
    in
    flake
    // {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = flake.legacyPackages.aarch64-linux.mv.unstable;
        modules = [ flake.nixOnDroidConfiguration ];
      };
    };
}
