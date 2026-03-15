{
  flake.nixosModules.caddy =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.caddyTailscaleProxy;
      inherit (lib) mkIf mkOption types;
    in
    {
      options.caddyTailscaleProxy = {
        domain = mkOption {
          type = types.str;
          default = "";
          example = "goofeus.tail-xxxxx.ts.net";
          description = ''
            Base Tailscale magic DNS domain for subdomain routing.
            Subdomains will be: immich.<domain>, glance.<domain>.
            Set this to enable the reverse proxy (e.g. in your host config).
          '';
        };
      };

      config = mkIf (cfg.domain != "") {
        services.caddy = {
          enable = true;
          # Caddy 2.5+ automatically fetches TLS certs from Tailscale for *.ts.net - no config needed
          virtualHosts = {
            immich = {
              hostName = "immich.${cfg.domain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.immich.port}
              '';
            };
            glance = {
              hostName = "glance.${cfg.domain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.glance.settings.server.port}
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
    };
}
