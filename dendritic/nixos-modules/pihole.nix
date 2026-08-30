# Pi-hole in Podman (host network) + Unbound upstream on 127.0.0.1:5335.
# Admin password: PIHOLE_PASSWORD in glance-env.age → FTLCONF_webserver_api_password at runtime.
{
  flake.nixosModules.pihole =
    {
      config,
      lib,
      pkgs,
      ...
    }:
  let
    cfg = config.services.pihole;
    unboundPort = 5335;
    piholeEnvFile = "/run/pihole/container.env";

    # Pre-pull amd64 image so first boot needs no registry lookup during DNS bring-up.
    # docker manifest inspect pihole/pihole:latest (linux/amd64)
    digest = "sha256:f7d1be836e3bc608b56d82fc9904f5a831cdfbc0dc9c6d58f94e4c985c70038b";

    piholeImage = pkgs.dockerTools.pullImage {
      imageName = "pihole/pihole";
      imageDigest = digest;
      finalImageName = "pihole/pihole";
      finalImageTag = "latest";
      os = "linux";
      arch = "amd64";
      sha256 = "sha256-QHBtqFdj/Z9vkRhvS3ccPxrn3mYSEHrLR+vDe22K1p8=";
    };

    postinit = pkgs.writeShellScript "pi-hole-postinit.sh" ''
      set -euo pipefail

      while ! ${pkgs.podman}/bin/podman exec -i pi-hole true 2>/dev/null; do
        sleep 1
      done

      ${pkgs.podman}/bin/podman exec -i pi-hole sh -lc 'printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" >/etc/resolv.conf'
      ${pkgs.podman}/bin/podman exec -i pi-hole pihole -g
      ${pkgs.podman}/bin/podman exec -i pi-hole sh -lc 'printf "nameserver 127.0.0.1\nnameserver ::1\noptions edns0 trust-ad\n" >/etc/resolv.conf'
    '';

    # Loopback HTTP only — Caddy (px + tailnet) reverse-proxies this port.
    webserverLoopback = "127.0.0.1:${toString cfg.webPort}o,[::1]:${toString cfg.webPort}o";

    piholeEnvScript = pkgs.writeShellScript "pihole-env.sh" ''
      set -euo pipefail
      ${pkgs.coreutils}/bin/mkdir -p /run/pihole
      password=$(${pkgs.gnugrep}/bin/grep -E '^PIHOLE_PASSWORD=' "${config.age.secrets.glance-env.path}" | ${pkgs.coreutils}/bin/cut -d= -f2-)
      printf 'FTLCONF_webserver_api_password=%s\nFTLCONF_webserver_port=%s\n' "$password" '${webserverLoopback}' > ${piholeEnvFile}
    '';
  in
  {
    options.services.pihole.webPort = lib.mkOption {
      type = lib.types.port;
      default = 8053;
      description = "Loopback-only HTTP port for Pi-hole web UI and API; fronted by Caddy.";
    };

    config = {
      services.resolved.enable = lib.mkForce false;
    services.dnsmasq.enable = lib.mkForce false;

    networking.nameservers = lib.mkForce [
      "127.0.0.1"
      "::1"
    ];

    networking.firewall.allowedTCPPorts = [
      53
    ];
    networking.firewall.allowedUDPPorts = [
      53
      67
    ];
    # Belt-and-suspenders: DNS from tailnet clients hitting Goofeus TS IP.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 53 ];
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];

    virtualisation.oci-containers.backend = "podman";

    systemd.services.podman-pi-hole = {
      after = [
        "unbound.service"
        "pihole-env.service"
      ];
      requires = [
        "unbound.service"
        "pihole-env.service"
      ];
    };

    systemd.services.pihole-env = {
      description = "Map glance-env PIHOLE_PASSWORD to Pi-hole container env";
      before = [ "podman-pi-hole.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = piholeEnvScript;
      };
    };

    systemd.services.pi-hole-postinit = {
      description = "One-time post-init inside pi-hole container";
      after = [ "podman-pi-hole.service" ];
      requires = [ "podman-pi-hole.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "!/var/lib/pi-hole-postinit.stamp";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = postinit;
        ExecStartPost = ''
          ${pkgs.coreutils}/bin/mkdir -p /var/lib
          ${pkgs.coreutils}/bin/touch /var/lib/pi-hole-postinit.stamp
        '';
      };
    };

    systemd.services.glance = lib.mkIf config.services.glance.enable {
      after = lib.mkAfter [ "podman-pi-hole.service" ];
      wants = [ "podman-pi-hole.service" ];
    };

    systemd.tmpfiles.rules = [
      "d /pi-hole/data/etc-pihole     0755 root root - -"
      "d /pi-hole/data/etc-dnsmasq.d  0755 root root - -"
      "d /run/pihole                  0755 root root - -"
    ];

    virtualisation.oci-containers.containers.pi-hole = {
      image = "pihole/pihole:latest";
      imageFile = piholeImage;
      autoStart = true;

      volumes = [
        "/pi-hole/data/etc-pihole:/etc/pihole"
        "/pi-hole/data/etc-dnsmasq.d:/etc/dnsmasq.d"
      ];

      environmentFiles = [ piholeEnvFile ];

      environment = {
        TZ = config.time.timeZone;
        DNSMASQ_USER = "root";
        FTLCONF_dns_upstreams = "127.0.0.1#${toString unboundPort}";
        # LOCAL mode ignores tailnet clients; ALL required for TS DNS override.
        FTLCONF_dns_listeningMode = "ALL";
        FTLCONF_dns_queryLogging = "false";
        FTLCONF_dns_rateLimit_count = "10000";
        FTLCONF_dns_rateLimit_interval = "60";
        FTLCONF_misc_privacylevel = "3";
      };

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cpus=0.5"
        "--memory=256m"
        "--network=host"
        # Pi-hole image healthcheck runs dig @127.0.0.1 pi.hole; fails during startup and
        # trips nixos-rebuild activation if conmon blocks on the first healthcheck oneshot.
        "--health-start-period=90s"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=5"
      ];

      podman = {
        sdnotify = "conmon";
      };
    };
    };
  };
}
