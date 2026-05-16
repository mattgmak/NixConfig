{ inputs, ... }:
{
  flake.homeModules.caelestia =
    {
      pkgs,
      config,
      ...
    }:
    {
      imports = [ inputs.caelestia-shell.homeManagerModules.default ];
      gtk.gtk4.theme = config.gtk.theme;
      gtk = {
        enable = true;
        iconTheme = {
          name = "Fluent";
          package = pkgs.fluent-icon-theme;
        };
      };

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
          services = {
            maxVolume = 1.5;
          };
          notifs = {
            actionOnClick = true;
          };
          osd = {
            enableMicrophone = true;
          };
          utilities = {
            toasts = {
              kbLayoutChanged = false;
            };
          };
          general = {
            apps = {
              terminal = [ "ghostty" ];
              audio = [
                "${
                  (pkgs.writeShellApplication {
                    name = "wiremix-term-audio";
                    text = "ghostty -e wiremix";
                  })
                }/bin/wiremix-term-audio"
              ];
              playback = [ "mpv" ];
              explorer = [
                "${
                  (pkgs.writeShellApplication {
                    name = "yazi-term-explorer";
                    text = ''ghostty -e yazi "$@"'';
                  })
                }/bin/yazi-term-explorer"
              ];
            };
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
                  returnAction = "dpms on";
                }
                {
                  timeout = 1800;
                  idleAction = [
                    "systemctl"
                    "suspend"
                  ];
                }
              ];
            };
          };
        };
        cli = {
          enable = true;
          settings = {
            theme.enableGtk = false;
          };
        };
      };

      home.file."Pictures/Wallpapers/wallpaper.jpg" = {
        source = ../nixos-modules/style/beautiful-mountains-landscape.jpg;
      };

      home.packages = [ pkgs.quickshell ];
    };
}
