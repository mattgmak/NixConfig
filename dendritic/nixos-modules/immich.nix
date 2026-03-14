{
  flake.nixosModules.immich = {
    services.immich = {
      enable = true;
      mediaLocation = "/mnt/2TBSeagateHDD/immich";
      user = "goofy";
    };
  };
}
