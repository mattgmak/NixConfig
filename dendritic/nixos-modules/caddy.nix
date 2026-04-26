{
  flake.nixosModules.caddy =
    {
      config,
      options,
      pkgs-for-homelab,
      lib,
      ...
    }:
    let
      copypartyPort =
        let
          p = config.services.copyparty.settings.p or 3923;
        in
        if lib.isList p then lib.elemAt p 0 else p;
      tailnetBaseDomain = "dab-octatonic.ts.net";
      tailnetFqdn = "goofeus.${tailnetBaseDomain}";
    in
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
          }
          // lib.optionalAttrs (options.services ? donetick && config.services.donetick.enable) {
            donetick = {
              hostName = "donetick.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.donetick.port}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.copyparty.enable {
            copyparty = {
              hostName = "copyparty.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString copypartyPort}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.jellyfin.enable {
            jellyfin = {
              hostName = "jellyfin.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:8096
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.sonarr.enable {
            sonarr = {
              hostName = "sonarr.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.sonarr.settings.server.port}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.radarr.enable {
            radarr = {
              hostName = "radarr.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.radarr.settings.server.port}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.prowlarr.enable {
            prowlarr = {
              hostName = "prowlarr.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.prowlarr.settings.server.port}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.bazarr.enable {
            bazarr = {
              hostName = "bazarr.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.bazarr.listenPort}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.transmission.enable {
            transmission = {
              hostName = "transmission.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString config.services.transmission.settings.rpc-port}
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.radicale.enable {
            radicale = {
              hostName = "radicale.${baseDomain}";
              extraConfig = ''
                reverse_proxy 127.0.0.1:5232 {
                  flush_interval -1
                }
                import cloudflare
              '';
            };
          }
          // lib.optionalAttrs config.services.nextcloud.enable (
            let
              nextcloudPhpConfig = ''
                root * ${config.services.nextcloud.finalPackage}
                root /store-apps/* ${config.services.nextcloud.home}
                root /nix-apps/* ${config.services.nextcloud.home}
                encode zstd gzip

                php_fastcgi unix//${config.services.phpfpm.pools.nextcloud.socket} {
                  env front_controller_active true
                }
                file_server

                header {
                  Strict-Transport-Security max-age=31536000;
                }

                redir /.well-known/carddav /remote.php/dav 301
                redir /.well-known/caldav /remote.php/dav 301
                redir /.well-known/webfinger /index.php/.well-known/webfinger 301
                redir /.well-known/nodeinfo /index.php/.well-known/nodeinfo 301

                @sensitive {
                  path /config/* /data/* /db_structure /.htaccess /.xml /README /3rdparty/* /lib/* /templates/* /occ /console.php /autotest* /issue* /indie* /db_* /build /build/* /tests /tests/*
                }
                respond @sensitive 404
              '';
              baseDomain = "px.goofy.me.in";
            in
            {
              # Caddy: public domain (Cloudflare TLS)
              nextcloud = {
                hostName = "nextcloud.${baseDomain}";
                extraConfig = ''
                  ${nextcloudPhpConfig}

                  import cloudflare
                '';
              };
              # Tailscale Serve: proxies to Caddy (tls internal for *.ts.net)
              nextcloud-ts = {
                hostName = tailnetFqdn;
                extraConfig = ''
                  tls internal
                  ${nextcloudPhpConfig}
                '';
              };
            }
          );
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

      # Tailscale serve: glance/immich directly; nextcloud via Caddy
      systemd.services.tailscale-serve =
        lib.mkIf
          (
            config.services.tailscale.enable
            && (
              config.services.glance.enable
              || config.services.immich.enable
              || config.services.nextcloud.enable
              || config.services.copyparty.enable
              || (options.services ? donetick && config.services.donetick.enable)
              || config.services.jellyfin.enable
              || config.services.sonarr.enable
              || config.services.radarr.enable
              || config.services.prowlarr.enable
              || config.services.bazarr.enable
              || config.services.transmission.enable
              || config.services.radicale.enable
            )
          )
          (
            let
              tailscalePkg = config.services.tailscale.package;
              mkServeDirect =
                service: port:
                lib.optionalString config.services.${service}.enable ''
                  tailscale serve --yes --service=svc:${service} --https=443 127.0.0.1:${toString port}
                '';
              # Nextcloud: TS Serve -> Caddy:443 -> PHP-FPM
              nextcloudServe = lib.optionalString config.services.nextcloud.enable "tailscale serve --yes --service=svc:nextcloud --https=443 127.0.0.1:443";
              glanceServe = mkServeDirect "glance" config.services.glance.settings.server.port;
              immichServe = mkServeDirect "immich" config.services.immich.port;
              copypartyServe = lib.optionalString config.services.copyparty.enable "tailscale serve --yes --service=svc:copyparty --https=443 127.0.0.1:${toString copypartyPort}";
              donetickServe = lib.optionalString (options.services ? donetick && config.services.donetick.enable) ''
                tailscale serve --yes --service=svc:donetick --https=443 127.0.0.1:${toString config.services.donetick.port}
              '';
              jellyfinServe = lib.optionalString config.services.jellyfin.enable ''
                tailscale serve --yes --service=svc:jellyfin --https=443 127.0.0.1:8096
              '';
              sonarrServe = lib.optionalString config.services.sonarr.enable ''
                tailscale serve --yes --service=svc:sonarr --https=443 127.0.0.1:${toString config.services.sonarr.settings.server.port}
              '';
              radarrServe = lib.optionalString config.services.radarr.enable ''
                tailscale serve --yes --service=svc:radarr --https=443 127.0.0.1:${toString config.services.radarr.settings.server.port}
              '';
              prowlarrServe = lib.optionalString config.services.prowlarr.enable ''
                tailscale serve --yes --service=svc:prowlarr --https=443 127.0.0.1:${toString config.services.prowlarr.settings.server.port}
              '';
              bazarrServe = lib.optionalString config.services.bazarr.enable ''
                tailscale serve --yes --service=svc:bazarr --https=443 127.0.0.1:${toString config.services.bazarr.listenPort}
              '';
              transmissionServe = lib.optionalString config.services.transmission.enable ''
                tailscale serve --yes --service=svc:transmission --https=443 127.0.0.1:${toString config.services.transmission.settings.rpc-port}
              '';
              radicaleServe = lib.optionalString config.services.radicale.enable ''
                tailscale serve --yes --service=svc:radicale --https=443 127.0.0.1:5232
              '';
            in
            {
              description = "Tailscale serve for homelab HTTP services (incl. Jellyfin and *Arr)";
              after = [ "tailscaled.service" ];
              wants = [ "tailscaled.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig.Type = "oneshot";
              serviceConfig.RemainAfterExit = true;
              path = [ tailscalePkg ];
              script = ''
                # Wait for Tailscale to be up
                for i in $(seq 1 30); do
                  if tailscale status &>/dev/null; then
                    break
                  fi
                  if [ $i -eq 30 ]; then
                    echo "Tailscale did not become ready in time"
                    exit 1
                  fi
                  sleep 2
                done
                tailscale cert ${tailnetFqdn}

                ${glanceServe}
                ${immichServe}
                ${copypartyServe}
                ${donetickServe}
                ${jellyfinServe}
                ${sonarrServe}
                ${radarrServe}
                ${prowlarrServe}
                ${bazarrServe}
                ${transmissionServe}
                ${radicaleServe}
                ${nextcloudServe}
              '';
            }
          );
    };
}
