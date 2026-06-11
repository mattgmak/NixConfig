# TREK: https://github.com/mauriceboe/TREK — OCI container from Nix-built image.
# Public: Tailscale Funnel (svc:trek). Tailnet: Tailscale Serve. See TREK.md at repo root.
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
      tailnetFunnelHost = "trek-goofeus.dab-octatonic.ts.net";
    in
    {
      options.services.trek = {
        enable = lib.mkEnableOption "TREK travel planner (OCI container, dev branch with Costs)";
        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "Host port (loopback only; Tailscale Serve/Funnel reach it externally).";
        };
        stateDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/2TBSeagateHDD/trek";
          description = "Host path for SQLite data and uploads.";
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
        publicUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://${tailnetFunnelHost}";
          description = "APP_URL — Tailscale Funnel/Serve URL for links and cookies.";
        };
        allowedOrigins = lib.mkOption {
          type = lib.types.str;
          default = "https://${tailnetFunnelHost}";
          description = "ALLOWED_ORIGINS (comma-separated).";
        };
        package = lib.mkOption {
          type = lib.types.package;
          default = trekImage;
          description = "Nix-built OCI image tarball (dendritic/packages/trek-image.nix).";
        };
      };

      config = lib.mkMerge [
        { services.trek.enable = lib.mkDefault true; }
        (lib.mkIf cfg.enable {
          systemd.services.trek-data-dir = {
            description = "Ensure TREK state directory on 2TB HDD";
            serviceConfig.Type = "oneshot";
            path = [ pkgs.util-linux ];
            wantedBy = [ "podman-trek.service" ];
            before = [ "podman-trek.service" ];
            after = [ "mnt-2TBSeagateHDD.mount" ];
            script = ''
              if mountpoint -q /mnt/2TBSeagateHDD; then
                mkdir -p "${cfg.stateDirectory}/data" "${cfg.stateDirectory}/uploads"
                chmod 0755 "${cfg.stateDirectory}" "${cfg.stateDirectory}/data" "${cfg.stateDirectory}/uploads"
              fi
            '';
          };

          virtualisation.oci-containers.containers.trek = {
            image = cfg.package.passthru.fullName;
            imageFile = "${cfg.package}/image.tar";
            autoStart = true;
            ports = [ "127.0.0.1:${toString cfg.port}:3000/tcp" ];
            volumes = [
              "${cfg.stateDirectory}/data:/app/data:rw"
              "${cfg.stateDirectory}/uploads:/app/uploads:rw"
            ];
            environment = {
              NODE_ENV = "production";
              PORT = "3000";
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
              "--health-cmd=wget -qO- http://localhost:3000/api/health || exit 1"
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
        })
      ];
    };
}
