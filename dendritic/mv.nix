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
              self.abyssJellyfinOverlay
            ];
          };
          # nix-on-droid takes a plain pkgs; no nixpkgs.overlays hook exists in
          # the droid config, so bake common-overlays in (tmax, …).
          mv-droid = inputs.multiverse.lib.mkMultiverse {
            inherit system;
            config.allowUnfree = true;
            overlays = self.common-overlays.${system};
          };
        in
        {
          mv = {
            unstable = mv.daysBehind "2026-08-13" 14;
            cursor = mv.daysBehind "2026-08-13" 14;
            vr = mv.daysBehind "2026-08-13" 14;
            homelab = mv-homelab.daysBehind "2026-08-13" 14;
            droid = mv-droid.daysBehind "2026-08-13" 14;
          };
        };
    };
}
