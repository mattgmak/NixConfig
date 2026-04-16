# Jellyfin + *Arr stack (TV, anime, movies) with Transmission on the HDD.
# Layout on the disk (under /mnt/2TBSeagateHDD/servarr): sonarr/{anime,tv}, radarr/movies,
# transmission/{daemon home + downloads}. Jellyfin libraries should use those same paths.
# Post-switch: set Sonarr/Radarr root folders to match, Prowlarr → apps, Transmission client,
# Bazarr → Sonarr/Radarr URLs + providers.
{ ... }:
{
  flake.nixosModules.arr =
    { lib, pkgs, ... }:
    let
      mediaMount = "/mnt/2TBSeagateHDD";
      servarrRoot = "${mediaMount}/servarr";
      sonarrRoot = "${servarrRoot}/sonarr";
      radarrRoot = "${servarrRoot}/radarr";
      transmissionRoot = "${servarrRoot}/transmission";
      transmissionHome = transmissionRoot;
    in
    {
      # Intel iGPU for Jellyfin QSV (headless still needs render nodes).
      hardware.graphics.enable = lib.mkDefault true;

      systemd.services.servarr-media-dirs = {
        description = "Create servarr library paths on the HDD";
        path = [ pkgs.util-linux ];
        requires = [ "mnt-2TBSeagateHDD.mount" ];
        after = [ "mnt-2TBSeagateHDD.mount" ];
        wantedBy = [ "multi-user.target" ];
        before = [
          "transmission.service"
          "sonarr.service"
          "radarr.service"
          "bazarr.service"
          "jellyfin.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RequiresMountsFor = [ mediaMount ];
        };
        script = ''
          if mountpoint -q ${mediaMount}; then
            mkdir -p \
              ${sonarrRoot}/anime \
              ${sonarrRoot}/tv \
              ${radarrRoot}/movies \
              ${transmissionRoot}/downloads/.incomplete

            chown sonarr:transmission ${sonarrRoot}
            chmod 2775 ${sonarrRoot}
            chown sonarr:transmission ${sonarrRoot}/anime ${sonarrRoot}/tv
            chmod 2775 ${sonarrRoot}/anime ${sonarrRoot}/tv

            chown radarr:transmission ${radarrRoot}
            chmod 2775 ${radarrRoot}
            chown radarr:transmission ${radarrRoot}/movies
            chmod 2775 ${radarrRoot}/movies

            chown transmission:transmission ${transmissionRoot}
            chmod 0750 ${transmissionRoot}
            chown transmission:transmission ${transmissionRoot}/downloads ${transmissionRoot}/downloads/.incomplete
            chmod 2775 ${transmissionRoot}/downloads
            chmod 2770 ${transmissionRoot}/downloads/.incomplete
          fi
        '';
      };

      users.users.sonarr.extraGroups = [ "transmission" ];
      users.users.radarr.extraGroups = [ "transmission" ];
      users.users.bazarr.extraGroups = [ "transmission" ];
      users.users.jellyfin.extraGroups = [
        "transmission"
        "video"
        "render"
      ];

      services.jellyfin = {
        enable = true;
        openFirewall = false;
        hardwareAcceleration = {
          enable = true;
          type = "qsv";
          device = "/dev/dri/renderD128";
        };
        transcoding.enableHardwareEncoding = true;
      };

      services.sonarr = {
        enable = true;
        openFirewall = false;
      };

      services.radarr = {
        enable = true;
        openFirewall = false;
      };

      services.prowlarr = {
        enable = true;
        openFirewall = false;
      };

      services.bazarr = {
        enable = true;
        openFirewall = false;
      };

      services.transmission = {
        enable = true;
        home = transmissionHome;
        downloadDirPermissions = "2775";
        openPeerPorts = true;
        openRPCPort = false;
        settings = {
          umask = "002";
          download-dir = "${transmissionRoot}/downloads";
          incomplete-dir = "${transmissionRoot}/downloads/.incomplete";
          incomplete-dir-enabled = true;
          rpc-bind-address = "127.0.0.1";
          # Reverse proxy (Caddy / tailscale serve) sends a public Host header; without
          # this, the web UI shows "could not connect to the server" (RPC host check).
          # RPC stays on loopback only, so disabling host whitelist is low risk.
          rpc-host-whitelist-enabled = false;
        };
      };
    };
}
