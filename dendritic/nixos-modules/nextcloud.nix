{
  flake.nixosModules.nextcloud =
    {
      config,
      lib,
      pkgs,
      pkgs-for-homelab,
      ...
    }:
    {
      services.nextcloud = {
        enable = true;
        package = pkgs-for-homelab.nextcloud32;
        hostName = "localhost";

        https = true;

        # Database: sqlite for simple setup, or pgsql for production
        database.createLocally = true;
        config.dbtype = "pgsql";

        # Required when behind Caddy/Tailscale reverse proxy
        settings.trusted_proxies = [ "127.0.0.1" ];
        # Domains clients use to reach Nextcloud (Caddy + Tailscale Serve)
        # Tailscale FQDN = hostname.tailnet.ts.net
        # localhost added by module; add access domains
        settings.trusted_domains = [
          "nextcloud.px.goofy.me.in"
          "goofeus.dab-octatonic.ts.net"
        ];
        # URL for CLI/links when accessed via proxy
        settings.overwrite.cli.url = "https://nextcloud.px.goofy.me.in";

        # Admin credentials - set via age secret (create with: echo -n 'yourpassword' | agenix -e secrets/nextcloud-admin-pass.age)
        config.adminuser = "admin";
        config.adminpassFile = config.age.secrets.nextcloud-admin-pass.path;

        # Optional: store data on HDD like Immich
        # datadir = "/mnt/2TBSeagateHDD/nextcloud";
        # home = "/var/lib/nextcloud";  # default, change if using custom datadir layout

        # Recommended: Redis for caching (improves performance)
        configureRedis = true;

        # App store: must be true to provide writable store-apps dir (needed for upgrade)
        # extraApps from Nix still take precedence; store used only if you install from web UI
        appstoreEnable = true;
        extraApps = { inherit (pkgs-for-homelab.nextcloud32Packages.apps) calendar; };
      };

      # Disable nginx – Caddy will serve Nextcloud via PHP-FPM
      services.nginx.enable = lib.mkForce false;

      # Allow Caddy to talk to PHP-FPM socket
      services.phpfpm.pools.nextcloud.settings = {
        "listen.owner" = config.services.caddy.user;
        "listen.group" = config.services.caddy.group;
      };
      users.users.caddy.extraGroups = [ "nextcloud" ];

      # PostgreSQL: two auth paths for Nextcloud
      # 1. Peer auth (Unix socket): for maintenance:install, nextcloud OS user → nextcloud/oc_admin DB user
      # 2. Trust (TCP localhost): PHP often connects via ::1 instead of socket; trust avoids password prompt
      services.postgresql.authentication = lib.mkBefore ''
        local nextcloud all peer map=nextcloud
        host nextcloud nextcloud 127.0.0.1/32 trust
        host nextcloud nextcloud ::1/128 trust
      '';
      services.postgresql.identMap = lib.mkAfter ''
        nextcloud nextcloud nextcloud
        nextcloud nextcloud oc_admin
      '';

      # Age secret for admin password
      age.secrets.nextcloud-admin-pass = {
        file = ../../secrets/nextcloud-admin-pass.age;
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0400";
      };

      fileSystems."/var/lib/nextcloud" = {
        device = "/mnt/2TBSeagateHDD/nextcloud";
        options = [ "bind" ];
      };

      # Ensure Nextcloud datadir exists on HDD (like immich)
      systemd.services.nextcloud-datadir = {
        description = "Ensure nextcloud owns its data directory on the HDD";
        serviceConfig.Type = "oneshot";
        path = [ pkgs.util-linux ];
        wantedBy = [
          "phpfpm-nextcloud.service"
          "nextcloud-setup.service"
        ];
        before = [
          "phpfpm-nextcloud.service"
          "nextcloud-setup.service"
        ];
        after = [ "mnt-2TBSeagateHDD.mount" ];
        script = ''
          if mountpoint -q /mnt/2TBSeagateHDD; then
            mkdir -p /mnt/2TBSeagateHDD/nextcloud
            chown -R nextcloud:nextcloud /mnt/2TBSeagateHDD/nextcloud
            chmod 2770 /mnt/2TBSeagateHDD/nextcloud
          fi
        '';
      };
    };
}
