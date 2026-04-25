# Offsite restic → Backblaze B2 (S3-compatible API). B2 server-side bucket encryption is optional; restic still encrypts client-side.
# Importing this module turns on the backup. Edit repository / s3 region / paths in place; `agenix -e` secrets: restic-password.age, restic-b2-env.age.
{
  flake.nixosModules.resticGoofeus =
    { config, ... }:
    {
      age.secrets = {
        restic-password = {
          file = ../../secrets/restic-password.age;
          mode = "0400";
        };
        restic-b2-env = {
          file = ../../secrets/restic-b2-env.age;
          mode = "0400";
        };
      };

      services.restic.backups.goofeus = {
        initialize = true;
        user = "root";
        passwordFile = config.age.secrets.restic-password.path;
        environmentFile = config.age.secrets.restic-b2-env.path;
        repository = "s3:https://s3.eu-central-003.backblazeb2.com/GoofeusBackup/";
        createWrapper = true;
        extraOptions = [ "s3.region=eu-central-003" ];
        paths = [
          "/mnt/2TBSeagateHDD/servarr"
          "/mnt/2TBSeagateHDD/immich"
          "/mnt/2TBSeagateHDD/copyparty"
          "/mnt/2TBSeagateHDD/donetick"
          "/var/lib/jellyfin"
          "/var/lib/sonarr"
          "/var/lib/radarr"
          "/var/lib/prowlarr"
          "/var/lib/bazarr"
          "/var/lib/caddy"
          "/var/lib/postgresql"
          "/var/lib/tailscale"
          "/var/lib/glance"
          "/var/lib/copyparty"
          "/var/lib/immich"
        ];
        exclude = [
          "/var/lib/docker"
          "**/.cache"
        ];
        extraBackupArgs = [ "--one-file-system" ];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
      };

      systemd.services."restic-backups-goofeus".unitConfig.RequiresMountsFor = [ "/mnt/2TBSeagateHDD" ];
    };
}
