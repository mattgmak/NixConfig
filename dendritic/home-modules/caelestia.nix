{ inputs, ... }:
{
  flake.homeModules.caelestia =
    {
      pkgs,
      lib,
      config,
      hostname,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;

      # The upstream derivation sets SETUPTOOLS_SCM_PRETEND_VERSION as an attribute.
      # Structured attrs do not export it, so hatch-vcs cannot read it.
      patchedCli =
        inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.default.overrideAttrs
          (old: {
            patchPhase = ''
              export SETUPTOOLS_SCM_PRETEND_VERSION=1
            '' + (old.patchPhase or "");
          });
    in
    {
      imports = [ inputs.caelestia-shell.homeManagerModules.default ];
      gtk.gtk4.theme.name = config.gtk.theme.name;
      # Icon theme managed by stylix.icons (shared with Qt via qt5ct/qt6ct).
      gtk.enable = true;

      # The shell wraps the CLI into its PATH, so the shell needs the patched copy too.
      programs.caelestia.cli.package = patchedCli;

      programs.caelestia = {
        enable = true;
        package = inputs.caelestia-shell.packages.${system}.with-cli.override {
          caelestia-cli = patchedCli;
        };
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

      # Keep in sync with dendritic/home-modules/hyprland/hyprland.nix (deskyMonitors.secondary).
      xdg.configFile."caelestia/monitors/HDMI-A-5/shell.json" = lib.mkIf (hostname == "GoofyDesky") {
        text = builtins.toJSON {
          lock.enabled = false;
        };
      };

      home.file."Pictures/Wallpapers/wallpaper.jpg" = {
        source = ../nixos-modules/style/beautiful-mountains-landscape.jpg;
      };

      home.file.".config/swappy/config".source = ./caelestia/swappy-config;

      home.packages = with pkgs; [
        quickshell
        swappy
      ];
    };
}
