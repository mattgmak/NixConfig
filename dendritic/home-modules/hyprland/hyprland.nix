{ inputs, self, ... }:
{
  flake.homeModules.hyprland =
    {
      pkgs,
      lib,
      config,
      hostname,
      ...
    }:
    let
      deskyMonitors = {
        primary = "DP-3";
        secondary = "HDMI-A-5";
      };
      electronLaunchFlags = "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --ignore-gpu-blacklist --enable-gpu-rasterization --enable-native-gpu-memory-buffers";
      woomerLaunch =
        if hostname == "GoofyDesky" then
          "woomer --monitor ${deskyMonitors.primary} --output ${deskyMonitors.primary}"
        else
          "woomer";
    in
    {
      imports = [
        self.homeModules.hyprlock
        self.homeModules.hyprpaper
      ];
      home.file.".config/hypr" = {
        recursive = true;
        source = ./hypr;
      };

      home.packages = with pkgs; [
        grim
        hyprpaper
        hypridle
        hyprpicker
        hyprpolkitagent
        inputs.hyprland.inputs.hyprland-guiutils.packages.${pkgs.stdenv.hostPlatform.system}.default
        hyprsunset
        hdrop
        libinput
        networkmanagerapplet
        pavucontrol
        pipewire
        slurp
        swayidle
        swaylock-effects
        wl-clipboard
        wlogout
        inputs.woomer.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
      xdg.configFile."uwsm/env".source =
        "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
      # Stylix's hyprland target still emits hyprlang-style top-level settings keys;
      # Home Manager maps those to invalid hl.decoration()/hl.general() calls in lua mode.
      stylix.targets.hyprland.enable = false;

      wayland.windowManager.hyprland = {
        package = null;
        portalPackage = null;
        enable = true;
        configType = "lua";
        systemd.enable = true;
        systemd.variables = [
          "--all"
        ];

        plugins = [
          pkgs.hyprlandPlugins.csgo-vulkan-fix
        ];

        sourceFirst = true;

        extraConfig =
          import ./lua/permissions.nix
          + import ./lua/monitors.nix { inherit hostname lib; }
          + "\n"
          + import ./lua/window-rules.nix { inherit hostname lib; }
          + "\n"
          + import ./lua/animations.nix
          + "\n"
          + import ./lua/csgo-vulkan-fix.nix
          + "\n"
          + import ./lua/autostart.nix { inherit hostname pkgs electronLaunchFlags; }
          + "\n"
          + import ./lua/binds.nix { inherit hostname lib woomerLaunch; };

        settings = {
          config = {
            ecosystem = {
              enforce_permissions = true;
            };
            binds = {
              scroll_event_delay = 100;
            };
            scrolling = {
              column_width = 0.7;
            };
            input = {
              kb_layout = "us";
              follow_mouse = 2;
              touchpad = {
                natural_scroll = true;
                disable_while_typing = 1;
                scroll_factor = 0.5;
              };
              sensitivity = if hostname == "GoofyDesky" then -0.3 else 0.5;
            };
            xwayland = {
              enabled = true;
              force_zero_scaling = true;
            };
            decoration = {
              rounding = 10;
              blur = {
                enabled = true;
                size = 3;
                passes = 3;
              };
              shadow = {
                color = "rgba(${config.lib.stylix.colors.base00}99)";
              };
            };
            animations = {
              enabled = true;
            };
            group = {
              col = {
                border_inactive = "rgb(${config.lib.stylix.colors.base03})";
                border_active = "rgb(${config.lib.stylix.colors.base0D})";
                border_locked_active = "rgb(${config.lib.stylix.colors.base0C})";
              };
              groupbar = {
                text_color = "rgb(${config.lib.stylix.colors.base05})";
                col = {
                  active = "rgb(${config.lib.stylix.colors.base0D})";
                  inactive = "rgb(${config.lib.stylix.colors.base03})";
                };
              };
            };
            misc = {
              background_color = "rgb(${config.lib.stylix.colors.base00})";
              disable_hyprland_logo = true;
            };
            general = {
              gaps_in = 5;
              gaps_out = 10;
              resize_on_border = true;
              border_size = if hostname == "GoofyDesky" then 2 else 1;
              col = {
                active_border = lib.mkForce "rgb(${config.lib.stylix.colors.base0E})";
                inactive_border = lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
              };
              allow_tearing = true;
            };
            cursor = {
              no_warps = true;
            };
          };
        };
      };
      xdg.portal = {
        enable = lib.mkForce true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-hyprland
          xdg-desktop-portal-gtk
        ];
        config = {
          preferred = {
            "org.freedesktop.impl.portal.Screenshot" = "hyprland";
            "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
            "org.freedesktop.impl.portal.GlobalShortcuts" = "hyprland";
            "org.freedesktop.impl.portal.InputCapture" = "hyprland";
          };
        };
      };

      # Upstream unit waits for graphical-session.target, but session units that
      # need the portal block on that same target — start the backend with the
      # main portal service instead.
      systemd.user.services.xdg-desktop-portal-hyprland = {
        unitConfig.After = lib.mkForce [
          "dbus.socket"
          "xdg-desktop-portal.service"
        ];
      };
    };
}
