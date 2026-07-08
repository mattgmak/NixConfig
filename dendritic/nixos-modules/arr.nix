# Jellyfin + *Arr stack (TV, anime, movies, music) with Transmission on the HDD.
# Layout: servarr/sonarr, servarr/radarr, syncthing/Music (Lidarr), servarr/transmission (daemon home + downloads/).
# Point Sonarr/Radarr root folders at sonarr/ and radarr/; Lidarr root folder at syncthing/Music
# (Syncthing shares that path to other devices). Jellyfin libraries same. Use a flat
# download dir in Transmission (no per-app subfolders) or match paths in *Arr download client settings.
# Post-switch: set Sonarr/Radarr/Lidarr root folders to match, Prowlarr → apps, Transmission client,
# Bazarr → Sonarr/Radarr URLs + providers. FlareSolverr listens on loopback only; in Prowlarr →
# Settings → General set FlareSolverr URL to http://127.0.0.1:8191.
#
# Abyss Jellyfin theme (https://github.com/AumGupta/abyss-jellyfin) is patched into
# jellyfin-web via flake.abyssJellyfinOverlay (dendritic/overlays/abyss-jellyfin-overlay.nix).
# - CSS @import URL is injected into index.html (CDN-loaded, no manual step)
# - Spotlight feature files (spotlight.html, spotlight.css, home-html chunk) are deployed
# - Home sections should be arranged manually: Settings > Home > Continue Watching,
#   Next Up, My Media, Recently Added (recommended by the theme)
{ ... }:
{
  flake.nixosModules.arr =
    {
      config,
      options,
      lib,
      pkgs,
      pkgs-for-homelab,
      ...
    }:
    let
      mediaMount = "/mnt/2TBSeagateHDD";
      servarrRoot = "${mediaMount}/servarr";
      sonarrRoot = "${servarrRoot}/sonarr";
      radarrRoot = "${servarrRoot}/radarr";
      syncthingRoot = "${mediaMount}/syncthing";
      musicRoot = "${syncthingRoot}/Music";
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
          "podman-transmission-gluetun.service"
          "podman-transmission.service"
          "sonarr.service"
          "radarr.service"
          "lidarr.service"
          "bazarr.service"
          "jellyfin.service"
        ];
        unitConfig.RequiresMountsFor = [ mediaMount ];
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          if mountpoint -q ${mediaMount}; then
            mkdir -p \
              ${servarrRoot} \
              ${sonarrRoot} \
              ${radarrRoot} \
              ${musicRoot} \
              ${transmissionRoot}/downloads/.incomplete \
              ${transmissionRoot}/downloads/complete

            # LinuxServer transmission init expects /downloads/complete and /downloads/incomplete.
            ln -sfn .incomplete ${transmissionRoot}/downloads/incomplete

            # Whole servarr tree: group "transmission" so Sonarr/Radarr/Bazarr/Jellyfin can traverse.
            chown root:transmission ${servarrRoot}
            chmod 2775 ${servarrRoot}

            chown sonarr:transmission ${sonarrRoot}
            chmod 2775 ${sonarrRoot}

            chown radarr:transmission ${radarrRoot}
            chmod 2775 ${radarrRoot}

            # Lidarr library; Syncthing (root on Goofeus) shares ${musicRoot} to other devices.
            chown lidarr:transmission ${musicRoot}
            chmod 2775 ${musicRoot}

            # Home 0750; downloads/ is 2775 so Sonarr/Radarr/Lidarr (group "transmission") can read imports.
            chown transmission:transmission ${transmissionRoot}
            chmod 0750 ${transmissionRoot}
            chown -R transmission:transmission ${transmissionRoot}/downloads
            chmod 2775 ${transmissionRoot}/downloads
            chmod 2770 ${transmissionRoot}/downloads/.incomplete
            # Repair perms on existing torrent data (skip .incomplete: stricter mode).
            (
              cd ${transmissionRoot}/downloads || exit 0
              find . \( -name .incomplete -prune \) -o -type d -exec chmod 2775 {} +
              find . \( -name .incomplete -prune \) -o -type f -exec chmod 664 {} +
            )
            if [ -d ${transmissionRoot}/downloads/.incomplete ]; then
              find ${transmissionRoot}/downloads/.incomplete -mindepth 1 -type d -exec chmod 2770 {} + 2>/dev/null || true
              find ${transmissionRoot}/downloads/.incomplete -mindepth 1 -type f -exec chmod 660 {} + 2>/dev/null || true
            fi
          fi
        '';
      };

      users.users.sonarr.extraGroups = [ "transmission" ];
      users.users.radarr.extraGroups = [ "transmission" ];
      users.users.lidarr.extraGroups = [ "transmission" ];
      users.users.bazarr.extraGroups = [ "transmission" ];
      users.users.jellyfin.extraGroups = [
        "transmission"
        "video"
        "render"
      ];

      # Jellyfin with Abyss theme (spotlight + CSS injected via jellyfin-web overlay).
      # Post-rebuild: hard-refresh browser (Ctrl+F5) to clear cached web UI.
      services.jellyfin = {
        enable = true;
        package = pkgs-for-homelab.jellyfin;
        openFirewall = false;
        hardwareAcceleration = {
          enable = true;
          type = "qsv";
          # First render node on typical single-iGPU box (i3-8100 UHD 630). Confirm: ls /dev/dri
          device = "/dev/dri/renderD128";
        };
        transcoding.enableHardwareEncoding = true;
      };

      # nixpkgs jellyfin only DeviceAllow's hardwareAcceleration.device; Intel VAAPI+QSV often
      # also needs the DRM primary node or init_hw_device fails ("unknown libva error"). Enumeration
      # varies (card0 vs card1 only); allow both so one-iGPU boxes match either layout.
      systemd.services.jellyfin.serviceConfig.DeviceAllow =
        lib.mkIf (config.services.jellyfin.enable && config.services.jellyfin.hardwareAcceleration.enable)
          (
            lib.mkForce [
              "${config.services.jellyfin.hardwareAcceleration.device} rw"
              "/dev/dri/card0 rw"
              "/dev/dri/card1 rw"
            ]
          );

      services.sonarr = {
        enable = true;
        package = pkgs-for-homelab.sonarr;
        openFirewall = false;
      };

      services.radarr = {
        enable = true;
        package = pkgs-for-homelab.radarr;
        openFirewall = false;
      };

      services.lidarr = {
        enable = true;
        package = pkgs-for-homelab.lidarr;
        openFirewall = false;
      };

      services.prowlarr = {
        enable = true;
        package = pkgs-for-homelab.prowlarr;
        openFirewall = false;
      };

      services.flaresolverr = {
        enable = true;
        package = pkgs-for-homelab.flaresolverr;
        openFirewall = false;
      };

      # Loopback only (no Caddy / tailscale serve); Prowlarr uses http://127.0.0.1:8191.
      systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

      services.bazarr = {
        enable = true;
        package = pkgs-for-homelab.bazarr;
        openFirewall = false;
      };

      services.transmission =
        lib.mkIf
          (!(lib.isOption options.services.transmissionGluetun && config.services.transmissionGluetun.enable))
          {
            enable = true;
            package = pkgs-for-homelab.transmission_4;
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
