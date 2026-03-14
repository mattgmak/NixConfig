{
  flake.nixosModules.immich =
    { config, pkgs, ... }:
    let
      port = config.services.immich.port;
    in
    {
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        mediaLocation = "/mnt/2TBSeagateHDD/immich";
      };

      systemd.services.immich-media-dir = {
        description = "Ensure immich owns its media directory on the HDD";
        serviceConfig.Type = "oneshot";
        path = [ pkgs.util-linux ];
        wantedBy = [ "immich-server.service" ];
        before = [ "immich-server.service" ];
        after = [ "mnt-2TBSeagateHDD.mount" ];
        script = ''
          if mountpoint -q /mnt/2TBSeagateHDD; then
            mkdir -p /mnt/2TBSeagateHDD/immich
            chown immich:immich /mnt/2TBSeagateHDD/immich
          fi
        '';
      };
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ port ];
    };
}
