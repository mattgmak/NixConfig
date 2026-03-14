{
  flake.nixosModules.homepage-dashboard =
    { config, pkgs-for-homelab, ... }:
    let
      port = config.services.homepage-dashboard.listenPort;
      immichPort = config.services.immich.port;
    in
    {
      services.homepage-dashboard = {
        enable = true;
        package = pkgs-for-homelab.homepage-dashboard;
        openFirewall = false;
        allowedHosts = "100.111.11.128:${toString port},goofeus:${toString port}";
        widgets = [
          {
            resources = {
              cpu = true;
              disk = "/";
              memory = true;
            };
          }
          {
            widget = {
              type = "immich";
              url = "http://localhost:${toString immichPort}";
              key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
              version = 2;
            };
          }
        ];
        environmentFile = "/etc/homepage-dashboard/environment";
      };
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ port ];
    };
}
