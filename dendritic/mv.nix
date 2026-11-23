{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    {
      legacyPackages =
        let
          mv = inputs.multiverse.lib.mkMultiverse {
            inherit system;
            config.allowUnfree = true;
          };
          mv-homelab = inputs.multiverse.lib.mkMultiverse {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              inputs.copyparty.overlays.default
              self.copypartyWrapperOverlay
              self.abyssJellyfinOverlay
            ];
          };
          # nix-on-droid takes a plain pkgs; no nixpkgs.overlays hook exists in
          # the droid config, so bake common-overlays in.
          mv-droid = inputs.multiverse.lib.mkMultiverse {
            inherit system;
            config.allowUnfree = true;
            overlays = self.common-overlays.${system};
          };
        in
        {
          mv = {
            unstable = mv.daysBehind "2026-08-13" 14;
            vr = mv.daysBehind "2026-08-13" 14;
            # Croc 11.6.5: v11.6.0 fixes the late-probe crash (schollz/croc#1396).
            # TODO: drop once the nixpkgs pin ships croc 11.6.5 or newer.
            croc = mv.at "2026-11-15";
            homelab = mv-homelab.daysBehind "2026-11-11" 14;
            droid = mv-droid.daysBehind "2026-08-13" 14;
          };
        };
    };
}
