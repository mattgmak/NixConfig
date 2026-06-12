# TREK: https://github.com/mauriceboe/TREK — OCI container from Nix-built image.
# Tailscale sidecar (trek-ts) joins the tailnet as hostname `trek` and exposes Serve + Funnel
# via TS_SERVE_CONFIG. TREK shares the sidecar network namespace. See TREK.md at repo root.
{
  flake.nixosModules.trek =
    {
      config,
      lib,
      pkgs,
      packages,
      ...
    }:
    let
      cfg = config.services.trek;
      trekImage = packages.trek-image;
      tailnetBaseDomain = "dab-octatonic.ts.net";
      tailnetHost = "${cfg.tailscaleHostname}.${tailnetBaseDomain}";

      tailscaleServeConfig = pkgs.writeTextDir "serve.json" ''
        {
          "TCP": {
            "443": {
              "HTTPS": true
            }
          },
          "Web": {
            "''${TS_CERT_DOMAIN}:443": {
              "Handlers": {
                "/": {
                  "Proxy": "http://127.0.0.1:${toString cfg.port}"
                }
              }
            }
          },
          "AllowFunnel": {
            "''${TS_CERT_DOMAIN}:443": ${lib.boolToString cfg.funnelEnable}
          }
        }
      '';
    in
    {
      options.services.trek = {
        enable = lib.mkEnableOption "TREK travel planner (OCI container, dev branch with Costs)";
        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "TREK listen port inside the shared sidecar network namespace.";
        };
        stateDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/2TBSeagateHDD/trek";
          description = "Host path for SQLite data, uploads, and Tailscale sidecar state.";
        };
        timezone = lib.mkOption {
          type = lib.types.str;
          default = config.time.timeZone or "Etc/UTC";
          description = "Container TZ.";
        };
        adminEmail = lib.mkOption {
          type = lib.types.str;
          default = "172981@gmail.com";
          description = "Initial admin email (first boot only, when no users exist).";
        };
        tailscaleHostname = lib.mkOption {
          type = lib.types.str;
          default = "trek";
          description = ''
            MagicDNS hostname for the Tailscale sidecar node
            (<hostname>.dab-octatonic.ts.net). Remove svc:trek from the admin console if
            migrating from Tailscale Services.
          '';
        };
        tailscaleTag = lib.mkOption {
          type = lib.types.str;
          default = "tag:trek";
          description = "Tailscale tag advertised by the sidecar (must exist in ACL tagOwners).";
        };
        funnelEnable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Expose TREK on the public internet via Tailscale Funnel.";
        };
        tailscaleImage = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/tailscale/tailscale:latest";
          description = "OCI image for the Tailscale sidecar container.";
        };
        tailscaleAcceptDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether the sidecar accepts MagicDNS from the tailnet. Leave false so
            tailscaled can resolve ACME (Let's Encrypt) via the host resolvers.
          '';
        };
        tailscaleDnsServers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          description = ''
            DNS servers for the sidecar (podman --dns). Public resolvers so
            tailscaled can resolve ACME (Let's Encrypt) without MagicDNS.
          '';
        };
        publicUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://${tailnetHost}";
          description = "APP_URL — Tailscale Serve/Funnel URL for links and cookies.";
        };
        allowedOrigins = lib.mkOption {
          type = lib.types.str;
          default = "https://${tailnetHost}";
          description = "ALLOWED_ORIGINS (comma-separated).";
        };
        package = lib.mkOption {
          type = lib.types.package;
          default = trekImage;
          description = "TREK image package (dendritic/packages/trek-image.nix); built on host via trek-image-build.service.";
        };
      };

      config = lib.mkMerge [
        { services.trek.enable = lib.mkDefault true; }
        (lib.mkIf cfg.enable {
          systemd.services.trek-data-dir = {
            description = "Ensure TREK state directory on 2TB HDD";
            serviceConfig.Type = "oneshot";
            path = [ pkgs.util-linux ];
            wantedBy = [
              "podman-trek-ts.service"
              "podman-trek.service"
            ];
            before = [
              "podman-trek-ts.service"
              "podman-trek.service"
            ];
            after = [ "mnt-2TBSeagateHDD.mount" ];
            script = ''
              if mountpoint -q /mnt/2TBSeagateHDD; then
                mkdir -p \
                  "${cfg.stateDirectory}/data" \
                  "${cfg.stateDirectory}/uploads" \
                  "${cfg.stateDirectory}/tailscale-state"
                chmod 0755 \
                  "${cfg.stateDirectory}" \
                  "${cfg.stateDirectory}/data" \
                  "${cfg.stateDirectory}/uploads" \
                  "${cfg.stateDirectory}/tailscale-state"
              fi
            '';
          };

          systemd.services.trek-image-build = {
            description = "Build TREK OCI image (${cfg.package.passthru.fullName})";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "trek-image-build";
            };
            wantedBy = [ "podman-trek.service" ];
            before = [ "podman-trek.service" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            path = [ pkgs.podman ];
            script = ''
              ${cfg.package}/bin/trek-image-build
            '';
          };

          virtualisation.oci-containers.containers.trek-ts = {
            image = cfg.tailscaleImage;
            autoStart = true;
            hostname = cfg.tailscaleHostname;
            environment = {
              TS_HOSTNAME = cfg.tailscaleHostname;
              TS_STATE_DIR = "/var/lib/tailscale";
              TS_SERVE_CONFIG = "/config/serve.json";
              TS_AUTH_ONCE = "true";
              TS_USERSPACE = "false";
              TS_ENABLE_HEALTH_CHECK = "true";
              TS_LOCAL_ADDR_PORT = "127.0.0.1:41234";
              TS_ACCEPT_DNS = lib.boolToString cfg.tailscaleAcceptDns;
              TS_EXTRA_ARGS = lib.concatStringsSep " " [
                "--advertise-tags=${cfg.tailscaleTag}"
                (lib.optionalString (!cfg.tailscaleAcceptDns) "--accept-dns=false")
              ];
            };
            environmentFiles = [ config.age.secrets.trek-tailscale-auth.path ];
            volumes = [
              "${cfg.stateDirectory}/tailscale-state:/var/lib/tailscale:rw"
              "${tailscaleServeConfig}:/config:ro"
            ];
            devices = [
              "/dev/net/tun:/dev/net/tun"
            ];
            extraOptions = [
              "--cap-add=NET_ADMIN"
              "--cap-add=NET_RAW"
              "--cap-add=SYS_MODULE"
            ]
            ++ map (dns: "--dns=${dns}") cfg.tailscaleDnsServers;
            podman = {
              sdnotify = "conmon";
            };
          };

          virtualisation.oci-containers.containers.trek = {
            image = cfg.package.passthru.fullName;
            autoStart = true;
            dependsOn = [ "trek-ts" ];
            networks = [ "container:trek-ts" ];
            volumes = [
              "${cfg.stateDirectory}/data:/app/data:rw"
              "${cfg.stateDirectory}/uploads:/app/uploads:rw"
            ];
            environment = {
              NODE_ENV = "production";
              PORT = toString cfg.port;
              TZ = cfg.timezone;
              FORCE_HTTPS = "true";
              TRUST_PROXY = "1";
              APP_URL = cfg.publicUrl;
              ALLOWED_ORIGINS = cfg.allowedOrigins;
              DISABLE_LOCAL_REGISTRATION = "true";
              ADMIN_EMAIL = cfg.adminEmail;
              LOG_LEVEL = "info";
            };
            environmentFiles = [ config.age.secrets.trek-env.path ];
            extraOptions = [
              "--read-only"
              "--security-opt=no-new-privileges:true"
              "--cap-drop=ALL"
              "--cap-add=CHOWN"
              "--cap-add=SETUID"
              "--cap-add=SETGID"
              "--tmpfs=/tmp:noexec,nosuid,size=64m"
              "--health-cmd=wget -qO- http://127.0.0.1:${toString cfg.port}/api/health || exit 1"
              "--health-interval=30s"
              "--health-timeout=10s"
              "--health-retries=3"
              "--health-start-period=15s"
            ];
            podman = {
              sdnotify = "healthy";
            };
          };

          age.secrets.trek-env = {
            file = ../../secrets/trek-env.age;
            mode = "0400";
          };

          age.secrets.trek-tailscale-auth = {
            file = ../../secrets/trek-tailscale-auth.age;
            mode = "0400";
          };
        })
      ];
    };
}
