# Radicale CalDAV/CardDAV — localhost + Caddy (public) + Tailscale serve.
# Replace the htpasswd secret: agenix -e secrets/radicale-htpasswd.age (see `man htpasswd` / htpasswd -nbBC 10 user).
{
  flake.nixosModules.radicale =
    {
      config,
      pkgs,
      pkgs-for-homelab,
      ...
    }:
    let
      dataDir = "/mnt/2TBSeagateHDD/radicale";
    in
    {
      services.radicale = {
        enable = true;
        package = pkgs-for-homelab.radicale;
        settings = {
          server.hosts = [ "127.0.0.1:5232" ];
          auth = {
            type = "htpasswd";
            htpasswd_filename = config.age.secrets.radicale-htpasswd.path;
            htpasswd_encryption = "bcrypt";
          };
          storage.filesystem_folder = dataDir;
        };
        rights = {
          root = {
            user = ".+";
            collection = "";
            permissions = "R";
          };
          principal = {
            user = ".+";
            collection = "{user}";
            permissions = "RW";
          };
          calendars = {
            user = ".+";
            collection = "{user}/[^/]+";
            permissions = "rw";
          };
        };
      };

      age.secrets.radicale-htpasswd = {
        file = ../../secrets/radicale-htpasswd.age;
        owner = "radicale";
        group = "radicale";
        mode = "0400";
      };

      systemd.services.radicale-data-dir = {
        description = "Ensure Radicale collections directory on 2TB disk";
        serviceConfig.Type = "oneshot";
        path = [ pkgs.util-linux ];
        wantedBy = [ "radicale.service" ];
        before = [ "radicale.service" ];
        after = [ "mnt-2TBSeagateHDD.mount" ];
        unitConfig.RequiresMountsFor = [ "/mnt/2TBSeagateHDD" ];
        script = ''
          if mountpoint -q /mnt/2TBSeagateHDD; then
            mkdir -p ${dataDir}
            chown radicale:radicale ${dataDir}
            chmod 0750 ${dataDir}
          else
            echo "radicale-data-dir: /mnt/2TBSeagateHDD is not mounted" >&2
            exit 1
          fi
        '';
      };

      systemd.services.radicale = {
        after = [ "radicale-data-dir.service" ];
        requires = [ "radicale-data-dir.service" ];
      };
    };
}
