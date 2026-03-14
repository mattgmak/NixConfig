{
  flake.nixosModules.homepage-dashboard = {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
    };
  };
}
