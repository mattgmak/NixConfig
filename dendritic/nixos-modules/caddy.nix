{
  flake.nixosModules.caddy =
    {
      config,
      ...
    }:
    {
      services.caddy = {
        enable = true;
        virtualHosts =
          let
            baseDomain = "px.goofy.me.in";
          in
          {
            glance = {
              hostName = "glance.${baseDomain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.glance.settings.server.port}
              '';
            };
            immich = {
              hostName = "immich.${baseDomain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.immich.port}
              '';
            };
          };
      };

      # Only Caddy needs ports on tailscale - services are reached via localhost
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
        80
        443
      ];

      # Allow Caddy (runs as non-root) to fetch Tailscale certs for *.ts.net
      services.tailscale.permitCertUid = "caddy";
    };
}
