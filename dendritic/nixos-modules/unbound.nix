# Recursive DNS upstream for Pi-hole: Mullvad DNS-over-TLS.
# Port 5335 — Pi-hole forwards to 127.0.0.1:5335 (not exposed on LAN firewall).
{
  flake.nixosModules.unbound =
    {
      config,
      lib,
      ...
    }:
  let
    unboundPort = 5335;
    mullvadForwarders = [
      "146.70.192.62@853#sg-sin-dns-101.mullvad.net"
      "185.213.155.123@853#de-fra-dns-001.mullvad.net"
    ];
  in
  {
    # Unbound TLS fails on first boot if system clock is wrong.
    services.timesyncd.servers = lib.mkDefault [
      "162.159.200.1"
      "162.159.200.123"
    ];

    systemd.services.unbound.restartIfChanged = true;

    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = [
            "0.0.0.0"
            "::0"
          ];
          port = unboundPort;

          access-control = [
            "127.0.0.1/32 allow"
            "192.168.50.0/24 allow"
            "100.64.0.0/10 allow"
          ];

          num-threads = 2;
          msg-cache-slabs = 2;
          rrset-cache-slabs = 2;
          infra-cache-slabs = 2;
          key-cache-slabs = 2;

          msg-cache-size = "32m";
          rrset-cache-size = "64m";

          prefetch-key = true;
          serve-expired = true;
          serve-expired-ttl = 86400;

          outgoing-range = 4096;
          num-queries-per-thread = 2048;

          harden-glue = true;
          harden-dnssec-stripped = true;
          use-caps-for-id = false;
          prefetch = true;
          edns-buffer-size = 1232;

          harden-below-nxdomain = true;
          harden-referral-path = true;
          qname-minimisation = true;

          hide-identity = true;
          hide-version = true;

          so-sndbuf = 0;
          so-rcvbuf = 0;

          verbosity = 0;
          log-queries = "no";
          log-replies = "no";
          log-servfail = "no";
          log-local-actions = "no";
        };

        forward-zone = [
          {
            name = ".";
            forward-addr = mullvadForwarders;
            forward-tls-upstream = true;
          }
        ];
      };
    };
  };
}
