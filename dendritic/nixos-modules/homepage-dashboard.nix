{
  flake.nixosModules.homepage-dashboard =
    let
      port = 8082;
    in
    {
      services.homepage-dashboard = {
        enable = true;
        openFirewall = false;
        allowedHosts = "100.111.11.128:${toString port},goofeus:${toString port}";
      };
      # Allow Tailscale nodes to access homepage-dashboard (port 8082)
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ port ];
    };
}
