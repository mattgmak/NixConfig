{
  flake.nixosModules.homepage-dashboard =
    { config, lib, ... }:
    let
      port = config.services.homepage-dashboard.listenPort;
      immichPort = config.services.immich.port;
    in
    {
      services.homepage-dashboard = {
        enable = true;
        openFirewall = false;
        allowedHosts = "100.111.11.128:${toString port},goofeus:${toString port}";
        # Add HOMEPAGE_VAR_IMMICH_KEY to environmentFiles for the widget to work.
        # Create an API key in Immich: Account Settings > API Keys (with server.statistics permission)
        widgets = lib.mkAfter [
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
