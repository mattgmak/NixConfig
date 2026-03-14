{
  flake.nixosModules.homepage-dashboard = {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = false;
      allowedHosts = "*";
    };
    # Allow Tailscale nodes to access homepage-dashboard (port 8082)
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8082 ];
  };
}
