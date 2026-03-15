{
  flake.nixosModules.immich =
    {
      pkgs,
      pkgs-for-homelab,
      ...
    }:
    {
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        mediaLocation = "/mnt/2TBSeagateHDD/immich";
        package = pkgs-for-homelab.immich;
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
            chmod 2770 /mnt/2TBSeagateHDD/immich
          fi
        '';
      };
    };
}
