{ ... }:
{
  flake.nixosModules.orca-slicer =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.orca-slicer
        pkgs.nanum # for fixing https://github.com/OrcaSlicer/OrcaSlicer/issues/11641
      ];
    };
}
