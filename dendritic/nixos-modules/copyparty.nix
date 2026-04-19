# copyparty: https://github.com/9001/copyparty#nixos-module
# Wire upstream module + overlay; defaults are conservative (disabled + localhost).
{ inputs, ... }:
{
  flake.nixosModules.copyparty =
    { config, pkgs-for-homelab, ... }:
    {
      imports = [ inputs.copyparty.nixosModules.default ];

      nixpkgs.overlays = [ inputs.copyparty.overlays.default ];

      services.copyparty = {
        enable = true;
        package = pkgs-for-homelab.copyparty;

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
          # WebDAV (rclone, etc.) editing files expects delete-on-replace semantics; see copyparty README §webdav.
          flags.daw = true;
        };

      };

      age.secrets.copyparty-goofy-pass = {
        file = ../../secrets/copyparty-goofy-pass.age;
        owner = config.services.copyparty.user;
        group = config.services.copyparty.group;
        mode = "0400";
      };
    };

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
          default = "";
          description = ''
            Account name for copyparty’s WebDAV cookie. Non-empty: cookie value is
            `cppwd=<this>:<password>` (named accounts). Empty: `cppwd=<password>` only.
            Matches copyparty docs/rclone.md (Cookie auth; avoids Basic auth issues behind redirects).
          '';
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
                urlNorm = if lib.hasSuffix "/" cfg.url then cfg.url else cfg.url + "/";
                urlLit = lib.escapeShellArg urlNorm;
                # copyparty expects Cookie cppwd=… (see docs/rclone.md); Basic auth can break
                # behind redirects (e.g. Tailscale serve) when Authorization is dropped.
                cookieUserPrefix = if cfg.webdavUser != "" then "${cfg.webdavUser}:" else "";
                cookieUserPrefixLit = lib.escapeShellArg cookieUserPrefix;
                remoteSection = lib.escapeShellArg "[${cfg.remoteName}]";
              in
              ''
                # bash
                set -euo pipefail
                MP=${mp}
                # Use uid in the path so a stale dir from `sudo -E` (root-owned under your
                # XDG_RUNTIME_DIR) does not block writes; $USER-named dirs are easy to poison.
                RUNDIR="''${XDG_RUNTIME_DIR:-/tmp}/rclone-copyparty-$(id -u)"
                if [[ -e "$RUNDIR" ]] && [[ ! -O "$RUNDIR" ]]; then
                  echo "copyparty-mount: $RUNDIR not owned by $(id -un); remove with: sudo rm -rf -- \"$RUNDIR\"" >&2
                  exit 1
                fi
                mkdir -p "$RUNDIR" "$MP"
                if [[ ! -w "$RUNDIR" ]]; then
                  echo "copyparty-mount: cannot write to $RUNDIR" >&2
                  exit 1
                fi
                if mountpoint -q "$MP"; then
                  echo "already mounted: $MP" >&2
                  exit 0
                fi
                pass="$(tr -d '\n' < ${passPath})"
                qual=${cookieUserPrefixLit}
                cookie_val="cppwd=''${qual}$pass"
                hdr_val_esc=$(printf '%s' "$cookie_val" | sed 's/"/""/g')
                conf="$RUNDIR/rclone.conf"
                cache="$RUNDIR/cache"
                # Root (e.g. sudo -E) can leave rclone.conf/cache here; you cannot overwrite or mkdir into them.
                for p in "$conf" "$cache"; do
                  if [[ -e "$p" ]] && [[ ! -O "$p" ]]; then
                    echo "copyparty-mount: $p is not owned by $(id -un); run: sudo rm -rf -- \"$p\"" >&2
                    exit 1
                  fi
                done
                # Previous run used chmod 400; owner still cannot `>`-truncate without write bit.
                rm -f "$conf"
                umask 0177
                {
                  printf '%s\n' ${remoteSection}
                  printf '%s\n' 'type = webdav'
                  printf '%s\n' 'vendor = owncloud'
                  printf 'url = %s\n' ${urlLit}
                  printf 'headers = "Cookie","%s"\n' "$hdr_val_esc"
                  printf '%s\n' 'auth_redirect = true'
                  printf '%s\n' 'pacer_min_sleep = 0.01ms'
                } > "$conf"
                chmod 400 "$conf"
                mkdir -p "$cache"
                # copyparty’s rclone.md uses 5s caches for same-machine benches; over Tailscale that
                # thrashes WebDAV and shows up as FUSE I/O errors. full + longer metadata cache is safer.
                exec rclone mount ${remote} "$MP" \
                  --config="$conf" \
                  --cache-dir="$cache" \
                  --disable-http2 \
                  --retries=10 \
                  --low-level-retries=20 \
                  --buffer-size=32M \
                  --vfs-cache-mode=full \
                  --vfs-cache-max-age=1h \
                  --vfs-read-ahead=128M \
                  --attr-timeout=1m \
                  --dir-cache-time=5m \
                  --daemon
              '';
          })
          (pkgs.writeShellApplication {
            name = "copyparty-unmount";
            runtimeInputs = [
              pkgs.fuse3
              pkgs.util-linux
            ];
            text =
              let
                mp = lib.escapeShellArg cfg.mountPoint;
              in
              ''
                # bash
                set -euo pipefail
                MP=${mp}
                if ! mountpoint -q "$MP"; then
                  echo "not mounted: $MP" >&2
                  exit 1
                fi
                # rclone FUSE mounts: many rclone builds have no `rclone umount`. On NixOS the
                # fusermount3 in PATH (nix store) is not setuid — use the system wrapper first.
                if [[ -x /run/wrappers/bin/fusermount3 ]]; then
                  exec /run/wrappers/bin/fusermount3 -u "$MP"
                fi
                if [[ -x /run/wrappers/bin/fusermount ]]; then
                  exec /run/wrappers/bin/fusermount -u "$MP"
                fi
                if command -v fusermount3 >/dev/null 2>&1; then
                  exec fusermount3 -u "$MP"
                fi
                if command -v fusermount >/dev/null 2>&1; then
                  exec fusermount -u "$MP"
                fi
                exec umount "$MP"
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
