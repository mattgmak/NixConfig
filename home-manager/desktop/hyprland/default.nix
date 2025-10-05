{ pkgs, lib, config, hostname, inputs, ... }: {
  imports = [ ./hyprlock.nix ./hyprpaper.nix ./hypridle.nix ./hyprsunset.nix ];
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
  ];
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
  wayland.windowManager.hyprland = {
    package = null;
    portalPackage = null;
    enable = true;
    systemd.enable = false;
    systemd.variables = [
      "DISPLAY"
      "HYPRLAND_INSTANCE_SIGNATURE"
      "WAYLAND_DISPLAY"
      "XDG_CURRENT_DESKTOP"
      "XDG_SESSION_DESKTOP"
      "XDG_SESSION_TYPE"
      "DESKTOP_SESSION"
    ];

    plugins =
      [ inputs.hyprland-plugins.packages.${pkgs.system}.csgo-vulkan-fix ];

    sourceFirst = true;
    settings = let
      deskyMonitors = {
        primary = "DP-3";
        secondary = "HDMI-A-5";
      };
      allWorkspacesIndex = lib.map (index: toString index) (lib.range 1 10);
      primaryWorkspaces = lib.take 5 allWorkspacesIndex; # ["1" "2" "3" "4" "5"]
      secondaryWorkspaces =
        lib.drop 5 allWorkspacesIndex; # ["6" "7" "8" "9" "10"]
    in {
      "$mod" = "ALT";
      unbind = [ ];
      bindin = [
        # "Super, catchall, global, caelestia:launcherInterrupt"
        # "Super, mouse:272, global, caelestia:launcherInterrupt"
        # "Super, mouse:273, global, caelestia:launcherInterrupt"
        # "Super, mouse:274, global, caelestia:launcherInterrupt"
        # "Super, mouse:275, global, caelestia:launcherInterrupt"
        # "Super, mouse:276, global, caelestia:launcherInterrupt"
        # "Super, mouse:277, global, caelestia:launcherInterrupt"
        # "Super, mouse_up, global, caelestia:launcherInterrupt"
        # "Super, mouse_down, global, caelestia:launcherInterrupt"
      ];
      bindlpt = [
        # Focus binds
        "$mod, R, focuswindow, initialtitle:(Zen Browser)"
        "$mod, E, focuswindow, class:(.*[Cc]ursor.*)"
        "$mod, W, focuswindow, class:(.*ghostty.*)"
        "$mod, Z, focuswindow, class:(vesktop)"
        "$mod, O, focuswindow, class:(OrcaSlicer)"
      ];
      bind = [
        "$mod, h, global, caelestia:launcher"
        "$mod SHIFT, h, exec, rofi -show drun"
        # "$mod, h, exec, sherlock"
        "$mod, y, exec, ${config.home.homeDirectory}/.config/sherlock/switch-windows.nu"
        "$mod, j, movefocus, u"
        "$mod, k, movefocus, d"
        "$mod, l, movefocus, l"
        "$mod, semicolon, movefocus, r"
        "$mod, Up, movefocus, u"
        "$mod, Down, movefocus, d"
        "$mod, Left, movefocus, l"
        "$mod, Right, movefocus, r"
        "$mod SHIFT, j, movewindow, u"
        "$mod SHIFT, k, movewindow, d"
        "$mod SHIFT, l, movewindow, l"
        "$mod SHIFT, semicolon, movewindow, r"
        "$mod SHIFT, Up, movewindow, u"
        "$mod SHIFT, Down, movewindow, d"
        "$mod SHIFT, Left, movewindow, l"
        "$mod SHIFT, Right, movewindow, r"
        "$mod, Tab, focuscurrentorlast"
        "$mod, t, togglefloating"
        "$mod, f, fullscreen"
        "$mod, d, killactive"
        "$mod, c, centerwindow"
        "$mod, G, workspace, name:Game"
        "$mod SHIFT, G, movetoworkspacesilent, name:Game"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, ~/.config/hypr/scripts/mic-toggle.sh"
        # ", XF86AudioPlay, exec, playerctl play-pause"
        # ", XF86AudioPause, exec, playerctl play-pause"
        # ", XF86AudioNext, exec, playerctl next"
        # ", XF86AudioPrev, exec, playerctl previous"
        # Waybar binds
        # "$mod SHIFT, M, exec, pkill waybar || waybar"
        # "$mod, M, exec, pkill -SIGUSR1 waybar"
        "$mod SHIFT, M, exec, caelestia shell --kill; caelestia shell -d"
        # Utility binds
        "SUPER, V, exec, ghostty --title=clipse -e clipse"
        "SUPER, B, exec, ghostty --title=bluetui -e bluetui"
        "SUPER, Q, exec, ghostty --title=btop -e btop"
        "SUPER, A, exec, ghostty --title=wiremix -e wiremix"
        "SUPER, M, exec, ghostty --title=nmtui -e nmtui"
        # ''SUPER SHIFT, S, exec, grim -g "$(slurp -w 0)" - | wl-copy''
        "Super Shift, S, global, caelestia:screenshotFreeze"
        "SUPER SHIFT, C, exec, hyprpicker -a"
        "SUPER, N, exec, makoctl dismiss -a"
        "SUPER, N, global, caelestia:clearNotifs"
        # App launch binds
        "SUPER, R, exec, zen"
        "SUPER, E, exec, cursor --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime"
        "SUPER, W, exec, ghostty"
        "SUPER, Z, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime"
        # Input toggle binds
        "SUPER, SPACE, exec, fcitx5-remote -t"
        # Logout bind
        "$mod, Q, exec, wlogout"
        # Floating terminal bind
        "SUPER, T, exec, ~/.config/hypr/scripts/floating-terminal.nu"
      ] ++ lib.concatMap (index:
        let key = if index == "10" then "0" else index;
        in [
          "$mod, ${key}, workspace, ${index}"
          "$mod SHIFT, ${key}, movetoworkspacesilent, ${index}"
        ]) allWorkspacesIndex;
      bindm =
        [ "$mod SHIFT, mouse:272, movewindow" "$mod, mouse:272, resizewindow" ];
      binde = [
        "$mod, u, resizeactive, 0 -20"
        "$mod, i, resizeactive, 0 20"
        "$mod, o, resizeactive, -20 0"
        "$mod, p, resizeactive, 20 0"
        "$mod SHIFT, u, moveactive, 0 -20"
        "$mod SHIFT, i, moveactive, 0 20"
        "$mod SHIFT, o, moveactive, -20 0"
        "$mod SHIFT, p, moveactive, 20 0"
        "$mod, Prior, resizeactive, 0 -20"
        "$mod, Next, resizeactive, 0 20"
        "$mod, Home, resizeactive, -20 0"
        "$mod, End, resizeactive, 20 0"
        "$mod SHIFT, Prior, moveactive, 0 -20"
        "$mod SHIFT, Next, moveactive, 0 20"
        "$mod SHIFT, Home, moveactive, -20 0"
        "$mod SHIFT, End, moveactive, 20 0"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 2.0 @DEFAULT_AUDIO_SINK@ 5%-"
        # ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        # ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindl = [
        ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
        ", XF86MonBrightnessDown, global, caelestia:brightnessDown"
        ", XF86AudioPlay, global, caelestia:mediaToggle"
        ", XF86AudioPause, global, caelestia:mediaToggle"
        ", XF86AudioNext, global, caelestia:mediaNext"
        ", XF86AudioPrev, global, caelestia:mediaPrev"
      ];

      monitor = if hostname == "GoofyDesky" then [
        "${deskyMonitors.primary}, 2560x1440@240.00Hz, 0x0, 1"
        "${deskyMonitors.secondary}, 1920x1080@144.00Hz, -1080x-650, 1, transform, 3"
      ] else [
        "eDP-1, highres, 0x0, 1"
        ", preferred, auto-up, 1"
      ];
      workspace = if hostname == "GoofyDesky" then
        [ "name:Game, monitor:${deskyMonitors.primary}" ]
        ++ lib.map (index: "name:${index}, monitor:${deskyMonitors.primary}")
        primaryWorkspaces
        ++ lib.map (index: "name:${index}, monitor:${deskyMonitors.secondary}")
        secondaryWorkspaces
      else
        [ ];

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
      gesture = [
        "3, horizontal, scale: 0.5, workspace"
        "3, vertical, scale: 0.5, fullscreen"
      ];
      exec-once = [
        # "uwsm app -- hyprpaper"
        "systemctl --user start hyprpolkitagent"
        # "uwsm app -- waybar"
        "uwsm app -- clipse -listen"
        "uwsm app -- fcitx5 -dr"
        "uwsm app -- fcitx5-remote -r"
        "uwsm app -- caelestia shell -d"
        (lib.mkIf (hostname != "GoofyDesky")
          "${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh")
        (lib.mkIf (hostname == "GoofyDesky")
          "hyprctl dispatch movecursor 1280 720")
        "uwsm app -- hyprsunset"
        "hyprctl hyprsunset temperature 4500"
        (lib.mkIf (hostname == "GoofyDesky") "vesktop")
        "gnome-keyring-daemon --start --components=secrets"
      ];
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
      };
      animations = {
        enabled = "yes";
        # bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        bezier = "myBezier, 0.10, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 4, myBezier"
          "windowsOut, 1, 4, myBezier"
          # "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 4, default"
          "workspaces, 1, 3, default"
        ];
      };

      plugin = {
        csgo-vulkan-fix = {
          res_w = 2560;
          res_h = 1440;
          class = "cs2";
        };
      };

      general = {
        # gaps_in = 2.5;
        # gaps_out = 5;
        gaps_in = 5;
        gaps_out = 10;
        resize_on_border = true;
        border_size = if hostname == "GoofyDesky" then 2 else 1;
        "col.active_border" =
          lib.mkForce "rgb(${config.lib.stylix.colors.base0E})";
        "col.inactive_border" =
          lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
        allow_tearing = true;
      };
      cursor = { no_warps = true; };
      windowrule = let
        matchPip = "title:^(Picture-in-Picture)$";
        matchFloatingTerminal = "title:(floating-terminal)";
        primaryWorkspacesMatcher =
          "onworkspace:r[${lib.head primaryWorkspaces}-${
            lib.last primaryWorkspaces
          }]";
        secondaryWorkspacesMatcher =
          "onworkspace:r[${lib.head secondaryWorkspaces}-${
            lib.last secondaryWorkspaces
          }]";
      in [
        "float, size 1200 800, title:(clipse|bluetui|nmtui|wiremix), ${primaryWorkspacesMatcher}"
        "float, size 1600 900, title:(btop), ${primaryWorkspacesMatcher}"
        "pin, float, ${matchPip}"
        # "center, floating:1, title:(Cursor)"
        "float, pin, center, stayfocused, size 60% 70%, ${matchFloatingTerminal}"
      ] ++ (if hostname == "GoofyDesky" then [
        "monitor ${deskyMonitors.secondary}, ${matchPip}"
        "noinitialfocus, move 72 20, size 986 555, ${matchPip}"
        "workspace name:Game, class:(org.prismlauncher.PrismLauncher|steam|Minecraft.*|cs2|osu!|steam_app_.*)"
        "fullscreen, immediate, class:(cs2|steam_app_.*)"
        "size 1000 800, title:(btop|clipse|bluetui|nmtui|wiremix), ${secondaryWorkspacesMatcher}"
        "workspace ${lib.head secondaryWorkspaces}, class:(vesktop)"
      ] else
        [ ]);
    };
  };
  xdg.portal = {
    enable = lib.mkForce true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
}
