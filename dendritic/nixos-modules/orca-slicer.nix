{
  flake.nixosModules.orca-slicer =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        orca-slicer
        nanum # for fixing https://github.com/OrcaSlicer/OrcaSlicer/issues/11641
      ];
    };
}
