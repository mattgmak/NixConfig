{
  flake.nixosModules.coredns =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.corednsTailscaleProxy;
      inherit (lib) mkIf mkOption types;
    in
    {
      options.corednsTailscaleProxy = {
        domain = mkOption {
          type = types.str;
          default = "";
          example = "goofeus.dab-octatonic.ts.net";
          description = ''
            Base Tailscale MagicDNS domain to resolve via split DNS.
            Resolves the domain and *.{domain} to this host's Tailscale IP.
            Set to the same value as caddyTailscaleProxy.domain when using both.
            Add this host's Tailscale IP as a restricted nameserver for this domain
            in the Tailscale admin console (DNS → Add nameserver → Custom).
          '';
        };
      };

      config = mkIf (cfg.domain != "") {
        # Oneshot to fetch Tailscale IP before CoreDNS starts
        systemd.services.coredns-tailscale-ip = {
          description = "Fetch Tailscale IP for CoreDNS split DNS";
          serviceConfig.Type = "oneshot";
          wantedBy = [ "coredns.service" ];
          before = [ "coredns.service" ];
          after = [ "tailscaled.service" ];
          path = [ pkgs.tailscale ];
          script = ''
            mkdir -p /run/coredns-tailscale
            for i in $(seq 1 30); do
              IP=$(tailscale ip -4 2>/dev/null)
              if [ -n "$IP" ]; then
                echo "TAILSCALE_IP=$IP" > /run/coredns-tailscale/env
                exit 0
              fi
              sleep 2
            done
            echo "Failed to get Tailscale IP after 60s" >&2
            exit 1
          '';
        };

        services.coredns = {
          enable = true;
          config = ''
            ${cfg.domain}:53 {
              bind 0.0.0.0
              template IN A {
                match ".*"
                answer "{{ .Name }} 60 IN A {$TAILSCALE_IP}"
                fallthrough
              }
              log
            }
          '';
        };

        # CoreDNS waits for Tailscale IP and reads it from env
        systemd.services.coredns = {
          after = [ "coredns-tailscale-ip.service" ];
          requires = [ "coredns-tailscale-ip.service" ];
          serviceConfig.EnvironmentFile = "/run/coredns-tailscale/env";
        };

        # Allow DNS on Tailscale interface for tailnet clients
        networking.firewall.interfaces."tailscale0".allowedUDPPorts = [ 53 ];
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 53 ];
      };
    };
}
