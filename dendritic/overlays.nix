{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Hyprland v0.56.2 requires glaze 7.x; nixpkgs-unstable ships glaze 9.0.0.
      glazeForHyprlandOverlay =
        _final: prev:
        prev.glaze.overrideAttrs (_old: {
          version = "7.9.1";
          src = prev.fetchFromGitHub {
            owner = "stephenberry";
            repo = "glaze";
            tag = "v7.9.1";
            hash = "sha256-NRRq5MGF2f5PW0teYnq58ELzson+U6KHVPaY6r30KLA=";
          };
        });

      glazeOverlay = final: prev: {
        glaze = glazeForHyprlandOverlay final prev;
      };

      # TODO: drop once nixpkgs ships node 24.22.1 in the binary cache.
      # nixpkgs nodejs_24 is 24.21.0 and embeds the revoked emSign ECC Root CA - G3,
      # so use the upstream build. nixpkgs nodejs_22 is 22.23.4, the first fixed 22.x
      # release, so it needs no pin. New attribute only: overriding nodejs_24 would
      # rehash every nixpkgs package that depends on it.
      nodeBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          node-bin = self.packages.${system}.node-bin;
        };

      tmaxOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-linux"
            "x86_64-darwin"
          ]
        ) {
          tmax = self.packages.${system}.tmax;
        };

      # Shared overlay stack: glaze 7.x + Hyprland packages (gcc16Stdenv).
      hyprlandBaseOverlays = [
        glazeOverlay
        inputs.hyprland.overlays.hyprland-packages
      ];

      hyprlandPackagesOverlay =
        _final: _prev:
        let
          hyprPkgs = import inputs.hyprland.inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = hyprlandBaseOverlays ++ [
              inputs.hyprland.overlays.hyprland-extras
            ];
          };
          # Plugins must use the same glazed hyprland — flake inputs build broken hyprland otherwise.
          pluginPkgs = import inputs.hyprland.inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = hyprlandBaseOverlays ++ [
              inputs.hyprland-plugins.overlays.hyprland-plugins
              inputs.hyprgrass.overlays.hyprgrass
            ];
          };
        in
        {
          inherit (hyprPkgs) hyprland xdg-desktop-portal-hyprland;
          hyprlandPlugins = pluginPkgs.hyprlandPlugins or { };
        };
    in
    {
      common-overlays = [
        hyprlandPackagesOverlay
        (_: _: {
          ghostty = inputs.ghostty.packages.${system}.default;
        })
        nodeBinOverlay
        tmaxOverlay
        self.agentBrowserOverlay
        self.tmuxMasterOverlay
        (_final: super: {
          direnv = super.direnv.overrideAttrs (_: {
            doCheck = false;
          });
        })
        inputs.nix4vscode.overlays.default
        inputs.coding-agents.overlays.default
        # Last so it wins over coding-agents' own pi-coding-agent tweaks: swap the node
        # build for the native Pi binary, which ships bin/pi for exactly this.
        # The compiled binary is the default on both supported systems.
        (
          _final: _super:
          {
            pi-coding-agent =
              if builtins.elem system [
                "x86_64-linux"
                "aarch64-darwin"
              ] then
                self.packages.${system}.piCompiled
              else
                self.packages.${system}.pi;
          }
        )
      ];

      common-nixpkgs-config = {
        allowUnfree = true;
      };
    };
}
