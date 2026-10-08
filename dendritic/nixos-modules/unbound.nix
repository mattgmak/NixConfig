# Recursive DNS upstream for Pi-hole: Cloudflare DNS-over-TLS.
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
    # Cloudflare anycast DoT, unfiltered: Pi-hole gravity is the only filtering layer.
    # Mullvad dropped 2026-10-08. Its nearest POP is Singapore, so from Goofeus every
    # cold lookup paid 39-49ms RTT, ~25% of TLS handshakes stalled at 380-420ms on that
    # lossy route, and unbound logged 162 ECONNREFUSED bursts on :853 in 10s. Cloudflare
    # answers from a Hong Kong POP: 2.1-2.5ms RTT, 5ms handshake+query, no stalls in 12
    # samples. Two addresses of one operator on purpose: mixing operators or filtering
    # profiles made the same name resolve differently query to query.
    # Verified 2026-10-08 with full TLS verification against both endpoints:
    #   dig +tls +tls-ca +tls-hostname=cloudflare-dns.com @1.1.1.1 example.com
    #   dig +tls +tls-ca +tls-hostname=cloudflare-dns.com @1.0.0.1 example.com
    dotForwarders = [
      "1.1.1.1@853#cloudflare-dns.com"
      "1.0.0.1@853#cloudflare-dns.com"
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

          # DoT upstream means every forward is a TCP connection: outgoing-num-tcp caps
          # concurrent connections to the DoT endpoints (default 10/thread), and
          # incoming-num-tcp caps connections from Pi-hole's dnsmasq (also 10/thread) —
          # dnsmasq uses TCP to Unbound whenever a client asks over TCP or a reply was
          # truncated. FTL's worst cluster was 15 "TCP connection failed while receiving
          # payload length from upstream" lines inside one second (2026-09-23 22:13:07),
          # i.e. above the old per-thread default.
          incoming-num-tcp = 128;
          outgoing-num-tcp = 64;

          # tcp-idle-timeout covers server-side (dnsmasq -> unbound) connections and
          # defaults to 30s, so FTL reopens TCP constantly; 5 min cuts that local churn.
          tcp-idle-timeout = 300000;
          # Documented for authority servers; measured inert for forwarders, where
          # unbound closes DoT sockets itself after <20s, so 600s never binds.
          tcp-reuse-timeout = 600000;

          harden-glue = true;
          harden-dnssec-stripped = true;
          use-caps-for-id = false;
          prefetch = true;
          edns-buffer-size = 1232;

          # max-udp-size caps UDP responses to clients; edns-buffer-size above only caps
          # what Unbound advertises upstream. Up to 1232 a TC flag makes dnsmasq retry
          # over TCP, so a higher value removes that path. Measured caveat: no query
          # sampled on Goofeus (DO=1 DNSKEY/NS/DNS lookups included) exceeded 769 bytes,
          # so this is defensive, not a proven cause of FTL's TCP warnings.
          # 1452 = 1500 MTU minus IPv6 (40+8) headers: largest payload that cannot
          # fragment on either IPv4 or IPv6 ethernet paths.
          max-udp-size = 1452;

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
            forward-addr = dotForwarders;
            forward-tls-upstream = true;
          }
        ];
      };
    };
  };
}
