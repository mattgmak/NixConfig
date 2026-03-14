{
  flake.nixosModules.homepage-dashboard =
    { config, ... }:
    let
      port = config.services.homepage-dashboard.listenPort;
    in
    {
      services.homepage-dashboard = {
        enable = true;
        openFirewall = false;
        allowedHosts = "100.111.11.128:${toString port},goofeus:${toString port}";
      };
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ port ];
    };
}
