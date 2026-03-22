# copyparty: https://github.com/9001/copyparty#nixos-module
# Wire upstream module + overlay; defaults are conservative (disabled + localhost).
{ inputs, ... }:
{
  flake.nixosModules.copyparty =
    { config, ... }:
    {
      imports = [ inputs.copyparty.nixosModules.default ];

      nixpkgs.overlays = [ inputs.copyparty.overlays.default ];

      services.copyparty = {
        enable = true;

        # Dedicated user is typical; adjust if you need group access to /mnt/2TBSeagateHDD.
        user = "copyparty";
        group = "copyparty";

        accounts = {
          goofy.passwordFile = config.age.secrets.copyparty-goofy-pass.path;
        };

        # Maps to copyparty [global]; see `copyparty --help` / upstream module docs.
        # Binds loopback only; Caddy (px.goofy.me.in) and `tailscale serve` reach it on 127.0.0.1:3923.
        settings = {
          i = "127.0.0.1";
          p = 3923;
          # Trust Caddy’s forwarded client IP (see https://github.com/9001/copyparty/blob/hovudstraum/docs/xff.md )
          xff-hdr = "X-Forwarded-For";
          xff-src = "127.0.0.1";
          rproxy = 1;
        };

        volumes."/" = {
          path = "/mnt/2TBSeagateHDD/copyparty";
          access.A = [ "goofy" ];
        };

      };

      age.secrets.copyparty-goofy-pass = {
        file = ../../secrets/copyparty-goofy-pass.age;
        owner = config.services.copyparty.user;
        group = config.services.copyparty.group;
        mode = "0400";
      };
    };

  # TODO: fix this
  # On-demand rclone WebDAV mount for copyparty (see copyparty/docs/rclone.md).
  flake.nixosModules.copyparty-client =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.copyparty-client;
    in
    {
      options.programs.copyparty-client = {
        enable = lib.mkEnableOption "copyparty-mount and copyparty-unmount commands (rclone WebDAV)";

        url = lib.mkOption {
          type = lib.types.str;
          description = "WebDAV base URL (e.g. https://host.tailnet.ts.net/).";
        };

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/copyparty";
          description = "Local mount directory; must be user-owned for unprivileged FUSE (use localUser).";
        };

        passwordFile = lib.mkOption {
          type = lib.types.str;
          description = "Filesystem path to the plaintext copyparty account password (e.g. age secret path).";
        };

        webdavUser = lib.mkOption {
          type = lib.types.str;
          description = "copyparty WebDAV username (account name on the server).";
        };

        remoteName = lib.mkOption {
          type = lib.types.str;
          default = "copyparty";
          description = "rclone remote name in the generated config.";
        };

        localUser = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            If set, creates programs.copyparty-client.mountPoint owned by this user via systemd-tmpfiles
            so unprivileged rclone mount can use it. Leave null if you manage the directory yourself.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "copyparty-mount";
            runtimeInputs = [ pkgs.rclone ];
            text =
              let
                passPath = lib.escapeShellArg cfg.passwordFile;
                mp = lib.escapeShellArg cfg.mountPoint;
                remote = lib.escapeShellArg "${cfg.remoteName}:/";
                urlLit = lib.escapeShellArg cfg.url;
                davUserLit = lib.escapeShellArg cfg.webdavUser;
                remoteSection = lib.escapeShellArg "[${cfg.remoteName}]";
              in
              ''
                set -euo pipefail
                MP=${mp}
                RUNDIR="''${XDG_RUNTIME_DIR:-/tmp}/rclone-copyparty-$USER"
                mkdir -p "$RUNDIR" "$MP"
                if mountpoint -q "$MP"; then
                  echo "already mounted: $MP" >&2
                  exit 0
                fi
                pass="$(tr -d '\n' < ${passPath})"
                obf="$(printf '%s' "$pass" | rclone obscure -)"
                umask 0177
                conf="$RUNDIR/rclone.conf"
                {
                  printf '%s\n' ${remoteSection}
                  printf '%s\n' 'type = webdav'
                  printf '%s\n' 'vendor = owncloud'
                  printf 'url = %s\n' ${urlLit}
                  printf 'user = %s\n' ${davUserLit}
                  printf 'pass = %s\n' "$obf"
                  printf '%s\n' 'pacer_min_sleep = 0.01ms'
                } > "$conf"
                chmod 400 "$conf"
                mkdir -p "$RUNDIR/cache"
                exec rclone mount ${remote} "$MP" \
                  --config="$conf" \
                  --cache-dir="$RUNDIR/cache" \
                  --vfs-cache-mode=writes \
                  --vfs-cache-max-age=5s \
                  --attr-timeout=5s \
                  --dir-cache-time=5s \
                  --daemon
              '';
          })
          (pkgs.writeShellApplication {
            name = "copyparty-unmount";
            runtimeInputs = [ pkgs.rclone ];
            text =
              let
                mp = lib.escapeShellArg cfg.mountPoint;
              in
              ''
                set -euo pipefail
                MP=${mp}
                if ! mountpoint -q "$MP"; then
                  echo "not mounted: $MP" >&2
                  exit 1
                fi
                exec rclone umount "$MP"
              '';
          })
          pkgs.rclone
        ];

        systemd.tmpfiles.settings = lib.mkIf (cfg.localUser != null) {
          "10-copyparty-client" = lib.listToAttrs [
            (lib.nameValuePair cfg.mountPoint {
              d = {
                mode = "0755";
                user = cfg.localUser;
                group = config.users.users.${cfg.localUser}.group;
              };
            })
          ];
        };
      };
    };
}
