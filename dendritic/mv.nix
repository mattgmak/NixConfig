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
        in
        {
          mv = {
            unstable = mv.daysBehind "2026-08-13" 14;
            cursor = mv.daysBehind "2026-08-13" 14;
            vr = mv.daysBehind "2026-08-13" 14;
            homelab = mv-homelab.daysBehind "2026-08-13" 14;
          };
        };
    };
}
