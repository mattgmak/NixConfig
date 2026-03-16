{
  flake.nixosModules.caddy =
    {
      config,
      pkgs-for-homelab,
      ...
    }:
    {
      services.caddy = {
        enable = true;
        package = pkgs-for-homelab.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/cloudflare@v0.2.3"
          ];
          hash = "sha256-bL1cpMvDogD/pdVxGA8CAMEXazWpFDBiGBxG83SmXLA=";
        };
        extraConfig = ''
          (cloudflare) {
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
              resolvers 1.1.1.1
            }
          }
        '';
        environmentFile = config.age.secrets.cloudflare-caddy.path;
        virtualHosts =
          let
            baseDomain = "px.goofy.me.in";
          in
          {
            glance = {
              hostName = "glance.${baseDomain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.glance.settings.server.port}
                import cloudflare
              '';
            };
            immich = {
              hostName = "immich.${baseDomain}";
              extraConfig = ''
                reverse_proxy :${toString config.services.immich.port}
                import cloudflare
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

      # Explicitly inject env file; nixpkgs module may not apply it with custom package
      # systemd.services.caddy.serviceConfig.EnvironmentFile =
      #   lib.mkForce config.age.secrets.cloudflare-caddy.path;

      age.secrets.cloudflare-caddy = {
        file = ../../secrets/cloudflare-caddy.age;
        owner = "caddy";
        group = "caddy";
      };
    };
}
