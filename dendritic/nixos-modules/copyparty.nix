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
        enable = lib.mkDefault true;

        # Dedicated user is typical; adjust if you need group access to /mnt/2TBSeagateHDD.
        user = lib.mkDefault "copyparty";
        group = lib.mkDefault "copyparty";

        # Maps to copyparty [global]; see `copyparty --help` / upstream module docs.
        # Binds loopback only; Caddy (px.goofy.me.in) and `tailscale serve` reach it on 127.0.0.1:3923.
        settings = {
          i = lib.mkDefault "127.0.0.1";
          p = lib.mkDefault 3923;
          # Trust Caddy’s forwarded client IP (see https://github.com/9001/copyparty/blob/hovudstraum/docs/xff.md )
          xff-hdr = lib.mkDefault "X-Forwarded-For";
          xff-src = lib.mkDefault "127.0.0.1";
          rproxy = lib.mkDefault 1;
        };

        volumes."/" = {
          path = "/mnt/2TBSeagateHDD/copyparty";
          access.r = "*";
        };

        # accounts = { };
        # groups = { };
      };
    };
}
