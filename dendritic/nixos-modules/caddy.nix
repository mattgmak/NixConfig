{
  flake.nixosModules.caddy =
    {
      config,
      lib,
      pkgs,
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
            Base Tailscale magic DNS domain. Path routing: / → Glance, /immich → Immich.
            Set this to enable the reverse proxy (e.g. in your host config).
          '';
        };
      };

      config = mkIf (cfg.domain != "") {
        services.caddy = {
          enable = true;
          # TODO: routing to /immich does not work
          configFile = pkgs.writeText "Caddyfile" ''
            ${cfg.domain} {
              handle_path /immich* {
                reverse_proxy :${toString config.services.immich.port}
              }
              handle {
                reverse_proxy :${toString config.services.glance.settings.server.port}
              }
            }
          '';
          # Caddy 2.5+ automatically fetches TLS certs from Tailscale for *.ts.net - no config needed
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
