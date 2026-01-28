{ inputs, withSystem, ... }: {
  perSystem = { system, ... }: {
    legacyPackages = let
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-for-cursor = import inputs.nixpkgs-for-cursor {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-for-osu = import inputs.nixpkgs-for-osu {
        inherit system;
        config.allowUnfree = true;
      };
    in { inherit pkgs-stable pkgs-for-cursor pkgs-for-osu; };
  };
  flake.nixpkgsConfig = { config, ... }: {
    nixpkgs.pkgs =
      withSystem config.nixpkgs.hostPlatform.system ({ pkgs, ... }: pkgs);
  };
}
