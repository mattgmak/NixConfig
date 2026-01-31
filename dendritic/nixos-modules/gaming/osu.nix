{
  perSystem = { inputs', ... }: {
    packages.osu-lazer-bin = inputs'.nix-gaming.packages.osu-lazer-bin;
  };
}
