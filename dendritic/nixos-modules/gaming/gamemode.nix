{
  flake.nixosModules.gamemode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.gamemode;
    in
    {
      programs.gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            renice = 10;
            inhibit_screensaver = 1;
          };
          cpu = {
            park_cores = "yes";
            preferring_cores = "auto";
          };
          gpu = {
            apply_gpu_optimisations = "accept-responsibility";
            gpu_device = 0;
          };
          custom = {
            start = ''${pkgs.libnotify}/bin/notify-send -t 3000 "GameMode" "Optimizations on"'';
            end = ''${pkgs.libnotify}/bin/notify-send -t 3000 "GameMode" "Optimizations off"'';
          };
        };
      };

      programs.steam.extraPackages = lib.mkIf config.programs.steam.enable [
        cfg.package
      ];

      environment.systemPackages = [
        (pkgs.makeDesktopItem {
          name = "steam-gamemode";
          desktopName = "Steam (GameMode)";
          genericName = "Game Manager";
          comment = "Steam with Feral GameMode performance tweaks";
          categories = [
            "Game"
            "Network"
          ];
          icon = "steam";
          exec = "${cfg.package}/bin/gamemoderun ${pkgs.steam}/bin/steam %U";
          mimeTypes = [ "x-scheme-handler/steam" ];
          startupWMClass = "steam";
        })
      ];
    };
}
