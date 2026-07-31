{
  description = "tmux picker for pi agent sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        agent-sesh = pkgs.buildGoModule {
          pname = "agent-sesh";
          version = "0.1.0";
          src = ./.;
          vendorHash = null;
          meta.mainProgram = "agent-sesh";
        };
        tmuxPlugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "agent-sesh";
          version = "0.1.0";
          src = ./plugin;
          extraDependencies = [ agent-sesh ];
          # tmux run-shell executes the rtp file directly; nix store copies are not +x by default.
          postInstall = ''
            chmod +x $target/agent_sesh.tmux
          '';
        };
      in
      {
        packages = {
          default = agent-sesh;
          inherit agent-sesh;
          agent-sesh-tmux = tmuxPlugin;
        };

        apps.default = {
          type = "app";
          program = "${agent-sesh}/bin/agent-sesh";
        };
      }
    )
    // {
      homeModules.agent-sesh =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          options.programs.agent-sesh = {
            enable = lib.mkEnableOption "agent-sesh tmux picker for pi sessions";
            package = lib.mkPackageOption self.packages.${system} "agent-sesh" { };
            tmuxKey = lib.mkOption {
              type = lib.types.str;
              default = "a";
              description = "tmux prefix key that opens the picker popup";
            };
            popupWidth = lib.mkOption {
              type = lib.types.str;
              default = "90%";
            };
            popupHeight = lib.mkOption {
              type = lib.types.str;
              default = "90%";
            };
          };

          config = lib.mkIf config.programs.agent-sesh.enable {
            home.packages = [ config.programs.agent-sesh.package ];
            programs.tmux.plugins = [
              {
                plugin = self.packages.${system}.agent-sesh-tmux;
                extraConfig = ''
                  set -g @agent-sesh-bind '${config.programs.agent-sesh.tmuxKey}'
                  set -g @agent-sesh-popup-width '${config.programs.agent-sesh.popupWidth}'
                  set -g @agent-sesh-popup-height '${config.programs.agent-sesh.popupHeight}'
                  set -g @agent-sesh-bin '${lib.getExe config.programs.agent-sesh.package}'
                '';
              }
            ];
          };
        };
    };
}
