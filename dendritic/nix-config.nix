{ self, ... }: {
  flake.nixConfig =
    { pkgs, ... }:
    {
      nix = {
        settings = {
          substituters = [
            "https://cache.nixos.org"
            # Only source for the cross-built proot-static paths nix-on-droid
            # release-24.05 hardcodes (upstream #545): Droid eval needs them.
            "https://nix-on-droid.cachix.org"
            "https://hyprland.cachix.org"
            "https://nix-community.cachix.org"
            "https://nix-gaming.cachix.org"
            "https://yazi.cachix.org"
            "https://cache.nixos-cuda.org"
          ];
          trusted-public-keys = [
            "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
            "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
            "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          ]
          ++ self.builderPublicKeys;
          warn-dirty = false;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          # nix-direnv roots the shell closure alone. Unrooted flake sources and
          # build-time deps die at GC, then a reload re-downloads every input.
          keep-outputs = true;
          keep-derivations = true;
        };
        gc = {
          options = "--delete-older-than 7d";
        }
        // (
          if pkgs.stdenv.isDarwin then
            {
              interval = {
                Hour = 8;
              };
            }
          else
            {
              automatic = true;
              dates = "daily";
            }
        );
      };

    };
}
