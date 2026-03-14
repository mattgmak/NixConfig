{
  flake.nixosModules.immich = { pkgs, ... }: {
    services.immich = {
      enable = true;
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
  };
}
