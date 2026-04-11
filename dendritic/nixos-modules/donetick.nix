# Donetick: https://github.com/donetick/donetick — Podman (OCI) + selfhosted.yaml
# Compose-equivalent: README Docker Compose; reverse proxy + Tailscale serve in caddy.nix
{
  flake.nixosModules.donetick =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.donetick;
      yamlTemplate = pkgs.writeText "donetick-selfhosted.yaml" ''
        name: "selfhosted"
        is_done_tick_dot_com: false
        is_user_creation_disabled: false
        telegram:
          token: ""
        pushover:
          token: ""
        database:
          type: "sqlite"
          migration: true
          host: "secret"
          port: 5432
          user: "secret"
          password: "secret"
          name: "secret"
        jwt:
          secret: "@JWT_PLACEHOLDER@"
          session_time: 168h
          max_refresh: 1440h
        server:
          port: 2021
          read_timeout: 10s
          write_timeout: 10s
          rate_period: 60s
          rate_limit: 300
          ${lib.concatStringsSep "\n" (
            [ "cors_allow_origins:" ]
            ++ map (o: "            - ${o}") (
              [
                "http://localhost:5173"
                "http://localhost:7926"
                "https://localhost"
                "http://localhost"
                "capacitor://localhost"
              ]
              ++ cfg.corsAllowOrigins
            )
          )}
          serve_frontend: true
          serve_swagger: true
          public_host: "${cfg.publicHost}"
        logging:
          level: "info"
          encoding: "json"
          development: false
        scheduler_jobs:
          due_job: 30m
          overdue_job: 3h
          pre_due_job: 3h
        email:
          host:
          port:
          key:
          email:
          user:
          appHost:
        oauth2:
          client_id:
          client_secret:
          auth_url:
          token_url:
          user_info_url:
          redirect_url:
          name:
        realtime:
          enabled: true
          sse_enabled: true
          heartbeat_interval: 60s
          connection_timeout: 120s
          max_connections: 1000
          max_connections_per_user: 5
          event_queue_size: 2048
          cleanup_interval: 2m
          stale_threshold: 5m
          enable_compression: true
          enable_stats: true
          allowed_origins:
            - "*"
      '';
    in
    {
      options.services.donetick = {
        enable = lib.mkEnableOption "Donetick (Podman OCI container)";
        port = lib.mkOption {
          type = lib.types.port;
          default = 2021;
          description = "Host port (bound to loopback only; use Caddy / Tailscale serve externally).";
        };
        stateDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/2TBSeagateHDD/donetick";
          description = "Host path for SQLite data and selfhosted.yaml.";
        };
        timezone = lib.mkOption {
          type = lib.types.str;
          default = config.time.timeZone or "Etc/UTC";
          description = "Container TZ (e.g. Asia/Hong_Kong).";
        };
        publicHost = lib.mkOption {
          type = lib.types.str;
          default = "https://donetick.px.goofy.me.in";
          description = "Public base URL (server.public_host) for links and OAuth redirects.";
        };
        corsAllowOrigins = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "https://donetick.px.goofy.me.in"
            "https://goofeus.dab-octatonic.ts.net"
          ];
          description = "Extra server.cors_allow_origins entries (YAML list lines).";
        };
      };

      config = lib.mkMerge [
        { services.donetick.enable = lib.mkDefault true; }
        (lib.mkIf cfg.enable (
          let
            writePy = pkgs.writeText "donetick-write-config.py" ''
              import pathlib

              jwt = pathlib.Path("${config.age.secrets.donetick-jwt.path}").read_text().strip()
              text = pathlib.Path("${yamlTemplate}").read_text()
              out = pathlib.Path("${cfg.stateDirectory}/config/selfhosted.yaml")
              out.parent.mkdir(parents=True, exist_ok=True)
              out.write_text(text.replace("@JWT_PLACEHOLDER@", jwt))
            '';
            writeConfig = pkgs.writeShellScript "donetick-write-config" ''
              set -euo pipefail
              install -d -m 0755 "${cfg.stateDirectory}/data" "${cfg.stateDirectory}/config"
              ${pkgs.python3Minimal}/bin/python3 ${writePy}
            '';
          in
          {
            systemd.services.donetick-data-dir = {
              description = "Ensure Donetick state directory on 2TB HDD";
              serviceConfig.Type = "oneshot";
              path = [ pkgs.util-linux ];
              wantedBy = [ "donetick-config.service" ];
              before = [ "donetick-config.service" ];
              after = [ "mnt-2TBSeagateHDD.mount" ];
              script = ''
                if mountpoint -q /mnt/2TBSeagateHDD; then
                  mkdir -p "${cfg.stateDirectory}/data" "${cfg.stateDirectory}/config"
                  chmod 0755 "${cfg.stateDirectory}" "${cfg.stateDirectory}/data" "${cfg.stateDirectory}/config"
                fi
              '';
            };

            systemd.services.donetick-config = {
              description = "Write Donetick selfhosted.yaml (JWT from agenix)";
              wantedBy = [ "multi-user.target" ];
              before = [ "podman-donetick.service" ];
              requiredBy = [ "podman-donetick.service" ];
              after = [
                "mnt-2TBSeagateHDD.mount"
                "donetick-data-dir.service"
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = "${writeConfig}";
            };

            virtualisation.oci-containers.containers.donetick = {
              image = "docker.io/donetick/donetick:v0.1.75-beta.15";
              autoStart = true;
              ports = [ "127.0.0.1:${toString cfg.port}:2021/tcp" ];
              volumes = [
                "${cfg.stateDirectory}/data:/donetick-data:rw"
                "${cfg.stateDirectory}/config:/config:rw"
              ];
              environment = {
                DT_ENV = "selfhosted";
                DT_SQLITE_PATH = "/donetick-data/donetick.db";
                TZ = cfg.timezone;
              };
              extraOptions = [
                "--health-cmd=wget --no-verbose --tries=1 --spider http://localhost:2021/api/v1/health || exit 1"
                "--health-start-period=1m"
                "--health-timeout=5s"
                "--health-interval=1m"
                "--health-retries=3"
              ];
              podman = {
                sdnotify = "healthy";
              };
            };

            age.secrets.donetick-jwt = {
              file = ../../secrets/donetick-jwt.age;
              mode = "0400";
            };
          }
        ))
      ];
    };
}
