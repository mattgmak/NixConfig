{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    let
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

      # Makes a branch worktree as agent, so hermes can run step 1 of the
      # nixconfig-worktree flow. See dendritic/packages/create-worktree.nix.
      createWorktreeOverlay =
        _final: _prev:
        {
          createWorktree = self.packages.${system}.createWorktree;
        };

      # pi for the hermes user, built from the same compiled derivation as the
      # agent user's pi. See dendritic/packages/pi-local.nix.
      piLocalOverlay =
        _final: _prev:
        {
          piLocal = self.packages.${system}.piLocal;
        };

      # The Hermes UI+ bridge for both Hermes tenants. See
      # dendritic/packages/hermes-ui-plus-bridge.nix.
      hermesUiPlusBridgeOverlay =
        _final: _prev:
        {
          hermesUiPlusBridge = self.packages.${system}.hermesUiPlusBridge;
        };

      # The lean-ctx CLI behind the hermes context engine plugin. See
      # dendritic/packages/lean-ctx.nix.
      leanCtxOverlay =
        _final: _prev:
        {
          lean-ctx = self.packages.${system}.lean-ctx;
        };

      # The autonomous deploy helpers for the hermes user. See
      # dendritic/packages/ramsay-deploy.nix.
      ramsayDeployOverlay =
        _final: _prev:
        {
          ramsayDeploy = self.packages.${system}.ramsayDeploy;
        };

      # Opens the agent tmux review session for a branch. One no-password sudo
      # command replaces the inline tmux recipe hermes used to run itself.
      # See dendritic/packages/spawn-approval-session.nix.
      spawnApprovalSessionOverlay =
        _final: _prev:
        {
          spawnApprovalSession = self.packages.${system}.spawnApprovalSession;
        };

      # Routes open and copy to the ssh client that owns the clipboard.
      # See dendritic/packages/tmux-bridge.nix.
      tmuxBridgeOverlay =
        _final: _prev:
        {
          tmuxBridge = self.packages.${system}.tmuxBridge;
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

      # TODO: drop once the nixpkgs pin ships btop 1.4.8 (pin 3ec636362e18 has 1.4.7).
      # 1.4.8 adds the amdgpu sysfs backend (PR #1661), which reports the Strix Halo
      # iGPU busy/temp/watts without rocm-smi or /dev/kfd access.
      btopOverlay =
        _final: prev:
        {
          btop = prev.btop.overrideAttrs (_old: {
            version = "1.4.8";
            __intentionallyOverridingVersion = true;
            src = prev.fetchFromGitHub {
              owner = "aristocratos";
              repo = "btop";
              tag = "v1.4.8";
              hash = "sha256-NujxQ6d8K+cRlwPfcoJk9XC0GDeh6Omx8x+WkCbxTcs=";
            };
          });
        };

      # Shared overlay stack: Hyprland packages (gcc16Stdenv).
      hyprlandBaseOverlays = [inputs.hyprland.overlays.hyprland-packages];

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
        createWorktreeOverlay
        piLocalOverlay
        hermesUiPlusBridgeOverlay
        leanCtxOverlay
        tmuxBridgeOverlay
        ramsayDeployOverlay
        spawnApprovalSessionOverlay
        tmaxOverlay
        btopOverlay
        self.agentBrowserOverlay
        self.tmuxMasterOverlay
        (_final: super: {
          direnv = super.direnv.overrideAttrs (_: {
            doCheck = false;
          });
          # test-buffer aborts (SIGABRT) at 5.20.0; upstream test regression at this pin.
          gtksourceview5 = super.gtksourceview5.overrideAttrs (_: {
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
