{ moduleWithSystem, ... }:
{
  flake.nixosModules.immich-ml = moduleWithSystem (
    perSystem@{ self' }:
    { pkgs, ... }:
    let
      mlPkg = perSystem.self'.legacyPackages.mv.homelab.immich.machine-learning;
    in
    {
      systemd.services.immich-ml = {
        description = "Immich machine learning (standalone, served to Goofeus)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment.MACHINE_LEARNING_CACHE_FOLDER = "/var/lib/immich-ml";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${mlPkg}/bin/machine-learning";
          DynamicUser = true;
          StateDirectory = "immich-ml";
          Restart = "on-failure";
          RestartSec = 3;
        };
      };

      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3003 ];
    }
  );
}
