# copyparty: https://github.com/9001/copyparty#nixos-module
# Wire upstream module + overlay; defaults are conservative (disabled + localhost).
{ inputs, ... }:
{
  flake.nixosModules.copyparty =
    { config, lib, ... }:
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
}
