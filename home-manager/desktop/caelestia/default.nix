{ inputs, pkgs, config, ... }: {
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
          timeouts = [
            {
              timeout = 300;
              idleAction = "lock";
            }
            {
              timeout = 600;
              idleAction = "dpms off";
              returnAction = "dpms on";
            }
            {
              timeout = 900;
              idleAction = [ "systemctl" "suspend-then-hibernate" ];
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
