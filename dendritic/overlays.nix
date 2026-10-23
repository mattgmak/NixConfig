{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    let
      # Hyprland v0.56.2 requires glaze 7.x; nixpkgs-unstable ships glaze 8.0.0.
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

      # TODO: drop once nixpkgs ships uv 0.13.4 in the binary cache.
      # nixpkgs uv trusts the revoked eMudhra roots, so use the upstream binary.
      uvBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          uv = self.packages.${system}.uvBin;
        };

      # TODO: drop once nixpkgs ships node 24.22.1 and 22.23.4 in the binary cache.
      # nixpkgs node embeds the revoked emSign ECC Root CA - G3, so use the upstream
      # build. New attributes only: overriding nodejs_24 or nodejs_22 would rehash
      # every nixpkgs package that depends on them.
      nodeBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          node-bin = self.packages.${system}.node-bin;
          node22-bin = self.packages.${system}.node22-bin;
        };

      # Linux only: upstream ships no tailscale tarball for darwin.
      tailscaleBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          prev.stdenv.hostPlatform.isLinux && self.packages.${system} ? tailscaleBin
        ) {
          tailscaleBin = self.packages.${system}.tailscaleBin;
        };

      # TODO: drop once nixpkgs ships yazi 26.9.1 in the binary cache.
      yaziBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (self.packages.${system} ? yaziBin) {
          yazi = self.packages.${system}.yaziBin;
        };

      # TODO: drop once nixpkgs ships bun 1.4.4 in the binary cache.
      # 1.4.4 drops the compromised eMudhra intermediates from the bundled store.
      bunBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          bun = self.packages.${system}.bunBin;
        };

      # TODO: drop once nixpkgs go_1_27 reaches 1.27.3 in the binary cache.
      # The pinned nixpkgs only carries go_1_27 = 1.27rc2, which keeps the chain.
      goBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          go = self.packages.${system}.goBin;
        };

      # TODO: drop once the pinned nixpkgs gleam is not a source build.
      # The source build needs the full Rust toolchain on every bump.
      gleamBinOverlay =
        _final: prev:
        prev.lib.optionalAttrs (
          builtins.elem prev.stdenv.hostPlatform.system [
            "aarch64-darwin"
            "x86_64-linux"
          ]
        ) {
          gleam = self.packages.${system}.gleamBin;
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
        uvBinOverlay
        nodeBinOverlay
        tailscaleBinOverlay
        yaziBinOverlay
        bunBinOverlay
        goBinOverlay
        gleamBinOverlay
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
        (_final: _super: {
          pi-coding-agent = self.packages.${system}.pi;
        })
      ];

      common-nixpkgs-config = {
        allowUnfree = true;
      };
    };
}
