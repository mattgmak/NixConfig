# Transmission behind Gluetun (PIA OpenVPN) — torrent traffic only through VPN.
# RPC stays on host loopback for Sonarr/Radarr, Caddy, and Tailscale Serve.
#
# Before deploy: cd secrets && agenix -e transmission-pia-vpn.age
#   OPENVPN_USER=p1234567
#   OPENVPN_PASSWORD=your-pia-password
#
# PIA port forwarding is unavailable in US regions; pick a non-US serverRegions value.
{
  flake.nixosModules.transmissionGluetun =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.transmissionGluetun;
      mediaMount = "/mnt/2TBSeagateHDD";
      servarrRoot = "${mediaMount}/servarr";
      transmissionRoot = "${servarrRoot}/transmission";
      gluetunState = "${transmissionRoot}/gluetun";
      # Tailscale Serve -> transmission.<tailnet>.ts.net; Caddy -> transmission.px.goofy.me.in.
      rpcHostWhitelist = "transmission.dab-octatonic.ts.net,goofeus.dab-octatonic.ts.net,transmission.px.goofy.me.in";

      cidrToRpcWildcard =
        cidr:
        let
          ip = lib.head (lib.splitString "/" cidr);
          octets = lib.splitString "." ip;
        in
        "${lib.elemAt octets 0}.${lib.elemAt octets 1}.*.*";

    in
    {
      options.services.transmissionGluetun = {
        enable = lib.mkEnableOption ''
          Transmission in Podman behind Gluetun (PIA). Disables the native
          services.transmission unit and routes peer traffic through the VPN.
        '';

        rpcPort = lib.mkOption {
          type = lib.types.port;
          default = 9091;
          description = "Transmission RPC port published on host loopback.";
        };

        serverRegions = lib.mkOption {
          type = lib.types.str;
          default = "Netherlands";
          description = ''
            Gluetun SERVER_REGIONS for PIA. Use a non-US region when port forwarding
            is enabled (PIA does not offer PF in the United States).
          '';
        };

        gluetunImage = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/qmcgaw/gluetun:v3";
          description = "Gluetun OCI image.";
        };

        transmissionImage = lib.mkOption {
          type = lib.types.str;
          default = "lscr.io/linuxserver/transmission:latest";
          description = "Transmission OCI image (shares Gluetun network namespace).";
        };
      };

      config = lib.mkIf cfg.enable (
        let
          podmanSubnets =
            config.virtualisation.podman.defaultNetwork.settings.subnets or [
              {
                gateway = "10.88.0.1";
                subnet = "10.88.0.0/16";
              }
            ];
          rpcIpWhitelist =
            "127.0.0.1," + lib.concatStringsSep "," (map cidrToRpcWildcard (map (s: s.subnet) podmanSubnets));
        in
        {
          # arr.nix omits services.transmission when this module is on, but a prior
          # generation may still have the native unit running on the same RPC port.
          systemd.services.transmission.enable = lib.mkForce false;

          systemd.services."podman-transmission-gluetun" = {
            conflicts = [ "transmission.service" ];
            after = [ "transmission.service" ];
          };

          users.users.transmission = {
            isSystemUser = true;
            group = "transmission";
            home = transmissionRoot;
            createHome = false;
          };

          users.groups.transmission = { };

          systemd.services.transmission-gluetun-dirs = {
            description = "Create Transmission VPN state directories on the HDD";
            path = [ pkgs.util-linux ];
            requires = [ "mnt-2TBSeagateHDD.mount" ];
            after = [ "mnt-2TBSeagateHDD.mount" ];
            wantedBy = [ "multi-user.target" ];
            before = [
              "podman-transmission-gluetun.service"
              "podman-transmission.service"
            ];
            unitConfig.RequiresMountsFor = [ mediaMount ];
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
                            if mountpoint -q ${mediaMount}; then
                              mkdir -p ${gluetunState}
                              chown transmission:transmission ${gluetunState}
                              chmod 0750 ${gluetunState}
                              cat > ${gluetunState}/set-transmission-port.sh <<'EOF'
              #!/bin/sh
              set -eu
              port="$1"
              rpc="http://127.0.0.1:${toString cfg.rpcPort}/transmission/rpc"
              for attempt in $(seq 1 40); do
                session=$(
                  wget -S --spider "$rpc" 2>&1 \
                    | grep -i "X-Transmission-Session-Id:" \
                    | head -1 \
                    | awk '{print $NF}' \
                    | tr -d '\r'
                ) || true
                if [ -n "''${session:-}" ]; then
                  response=$(wget -qO- --retry-connrefused \
                    --header="X-Transmission-Session-Id: ''${session}" \
                    --header="Content-Type: application/json" \
                    --post-data="{\"method\":\"session-set\",\"arguments\":{\"peer-port\":''${port}}}" \
                    "$rpc") || true
                  case "$response" in
                    *'"result":"success"'*) exit 0 ;;
                  esac
                fi
                sleep 3
              done
              echo "set-transmission-port: transmission RPC not ready" >&2
              exit 1
              EOF
                              chmod 0755 ${gluetunState}/set-transmission-port.sh
                              chown transmission:transmission ${gluetunState}/set-transmission-port.sh
                            fi
            '';
          };

          systemd.services.transmission-vpn-rpc-settings = {
            description = "Ensure Transmission RPC listens inside the Gluetun netns";
            requires = [ "mnt-2TBSeagateHDD.mount" ];
            after = [
              "mnt-2TBSeagateHDD.mount"
              "servarr-media-dirs.service"
            ];
            wantedBy = [ "multi-user.target" ];
            before = [ "podman-transmission.service" ];
            unitConfig.RequiresMountsFor = [ mediaMount ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              settings="${transmissionRoot}/settings.json"
              if [ ! -f "$settings" ]; then
                ${pkgs.transmission_4}/bin/transmission-daemon --config-dir ${transmissionRoot} --dump-settings > "$settings"
              fi
              ${pkgs.jq}/bin/jq \
                '.["rpc_bind_address"] = "0.0.0.0"
                | .["rpc_host_whitelist_enabled"] = true
                | .["rpc_host_whitelist"] = "${rpcHostWhitelist}"
                | .["rpc_whitelist_enabled"] = true
                | .["rpc_whitelist"] = "${rpcIpWhitelist}"
                | .["rpc_port"] = ${toString cfg.rpcPort}
                | .["download_dir"] = "${transmissionRoot}/downloads"
                | .["incomplete_dir"] = "${transmissionRoot}/downloads/.incomplete"
                | .["incomplete_dir_enabled"] = true
                | .["umask"] = "002"
                | .["peer_port_random_on_start"] = false
                | .["port-forwarding-enabled"] = false
                | .["ratio_limit_enabled"] = true
                | .["ratio_limit"] = 2
                | del(.["rpc-bind-address"], .["rpc-host-whitelist-enabled"], .["rpc-host-whitelist"], .["rpc-whitelist-enabled"], .["rpc-whitelist"], .["rpc-port"], .["download-dir"], .["incomplete-dir"], .["incomplete-dir-enabled"], .["peer-port-random-on-start"], .["ratio-limit-enabled"], .["ratio-limit"])' \
                "$settings" > "$settings.tmp"
              mv "$settings.tmp" "$settings"
              chown transmission:transmission "$settings"
              chmod 0600 "$settings"
              rm -f "${transmissionRoot}/custom-cont-init.d/99-disable-rpc-ip-whitelist.sh"
            '';
          };

          systemd.services.transmission-vpn-port-sync = {
            description = "Sync Transmission peer port with Gluetun PIA port forward";
            # Soft ordering only: Requires here deadlocks with podman-transmission
            # ExecStartPost (parent cannot be active until post finishes).
            after = [
              "podman-transmission-gluetun.service"
              "podman-transmission.service"
            ];
            path = [
              pkgs.podman
              pkgs.jq
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = 240;
            };
            script = ''
              for attempt in $(seq 1 36); do
                port=$(
                  podman exec transmission-gluetun wget -qO- http://127.0.0.1:8000/v1/portforward 2>/dev/null \
                    | ${pkgs.jq}/bin/jq -r .port
                ) || true
                if [ -n "''${port:-}" ] && [ "''${port}" != "null" ]; then
                  if podman exec transmission-gluetun /bin/sh /gluetun/set-transmission-port.sh "''${port}"; then
                    echo "transmission-vpn-port-sync: peer port set to ''${port}"
                    exit 0
                  fi
                fi
                sleep 5
              done
              echo "transmission-vpn-port-sync: failed to apply forwarded port" >&2
              exit 1
            '';
          };

          systemd.services."podman-transmission" = {
            serviceConfig.ExecStartPost = lib.mkAfter [
              "+${pkgs.systemd}/bin/systemctl start --no-block transmission-vpn-port-sync.service"
            ];
          };

          virtualisation.oci-containers.containers.transmission-gluetun = {
            image = cfg.gluetunImage;
            autoStart = true;
            ports = [
              "127.0.0.1:${toString cfg.rpcPort}:${toString cfg.rpcPort}/tcp"
            ];
            environment = {
              VPN_SERVICE_PROVIDER = "private internet access";
              VPN_TYPE = "openvpn";
              SERVER_REGIONS = cfg.serverRegions;
              PORT_FORWARD_ONLY = "on";
              VPN_PORT_FORWARDING = "on";
              FIREWALL = "on";
              DOT = "on";
              FIREWALL_OUTBOUND_SUBNETS = "127.0.0.0/8";
              VPN_PORT_FORWARDING_UP_COMMAND = "/bin/sh /gluetun/set-transmission-port.sh {{PORT}}";
            };
            environmentFiles = [ config.age.secrets.transmission-pia-vpn.path ];
            volumes = [
              "${gluetunState}:/gluetun:rw"
            ];
            devices = [
              "/dev/net/tun:/dev/net/tun"
            ];
            extraOptions = [
              "--cap-add=NET_ADMIN"
              # Host Tailscale MagicDNS adds search dab-octatonic.ts.net; without this,
              # Gluetun health/DNS checks for github.com also query github.com.<tailnet>.
              "--dns-search=."
              "--health-cmd=/gluetun-entrypoint healthcheck"
              "--health-interval=30s"
              "--health-timeout=10s"
              "--health-retries=5"
              "--health-start-period=60s"
            ];
            podman = {
              # conmon: do not block nixos-rebuild on VPN healthcheck; dependsOn
              # still orders Transmission after the Gluetun container exists.
              sdnotify = "conmon";
            };
          };

          virtualisation.oci-containers.containers.transmission = {
            image = cfg.transmissionImage;
            autoStart = true;
            dependsOn = [ "transmission-gluetun" ];
            networks = [ "container:transmission-gluetun" ];
            volumes = [
              "${transmissionRoot}:/config:rw"
              "${transmissionRoot}/downloads:/downloads:rw"
              # Same host path inside the container so settings.json matches Sonarr/Radarr.
              "${transmissionRoot}/downloads:${transmissionRoot}/downloads:rw"
            ];
            environment = {
              PUID = toString config.users.users.transmission.uid;
              PGID = toString config.users.groups.transmission.gid;
              TZ = config.time.timeZone;
              WEBUI_PORT = toString cfg.rpcPort;
              # LinuxServer init maps WHITELIST/HOST_WHITELIST to rpc-whitelist/rpc-host-whitelist.
              WHITELIST = rpcIpWhitelist;
              HOST_WHITELIST = rpcHostWhitelist;
            };
            extraOptions = [
              "--health-cmd=wget -qO- http://127.0.0.1:${toString cfg.rpcPort}/transmission/web/ || exit 1"
              "--health-interval=30s"
              "--health-timeout=10s"
              "--health-retries=3"
              "--health-start-period=30s"
            ];
            podman = {
              sdnotify = "healthy";
            };
          };

          age.secrets.transmission-pia-vpn = {
            file = ../../secrets/transmission-pia-vpn.age;
            mode = "0400";
          };
        }
      );
    };
}
