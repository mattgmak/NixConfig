{ inputs, pkgs, ... }: {
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    systemd.enable = false;
    settings = {
      bar = {
        workspaces = {
          activeLabel = " ";
          occupiedLabel = "  ";
          occupiedBg = true;
          label = "  ";
        };
      };
      notifs = { actionOnClick = true; };
      osd = { enableMicrophone = true; };
      general = {
        idle = {
          lockBeforeSleep = true;
          inhibitWhenAudio = true;
          timeouts = [
            {
              timeout = 600;
              idleAction = "lock";
            }
            {
              timeout = 900;
              idleAction = "dpms off";
              returnAction = "dpms on && hyprctl hyprsunset temperature 4500";
            }
            {
              timeout = 1200;
              idleAction = [ "systemctl" "suspend" ];
            }
          ];
        };
      };
    };
    cli = {
      enable = true;
      settings = { theme.enableGtk = false; };
    };
  };

  home.file."Pictures/Wallpapers/wallpaper.jpg" = {
    source = ../../../modules/style/beautiful-mountains-landscape.jpg;
  };

  home.packages = [ pkgs.quickshell ];
}
