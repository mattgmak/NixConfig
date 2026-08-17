{ inputs, ... }:
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
        (_final: super: {
          direnv = super.direnv.overrideAttrs (_: {
            doCheck = false;
          });
        })
        inputs.nix4vscode.overlays.default
        inputs.coding-agents.overlays.default
      ];

      common-nixpkgs-config = {
        allowUnfree = true;
      };
    };
}
