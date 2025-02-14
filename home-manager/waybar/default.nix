# https://github.com/Alexays/Waybar
{
  stylix.targets.waybar.enable = false;
  home.file.".config/waybar/toggl_status.py".source = ./toggl_status.py;
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ./style.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        mod = "dock";
        margin-left = 2;
        margin-right = 2;
        margin-top = 2;
        margin-bottom = 2;
        reload_style_on_change = true;
        spacing = 2;
        modules-left = [
          "custom/spacer"
          "hyprland/workspaces"
          "wlr/taskbar"
          "hyprland/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/toggl"
          "pulseaudio"
          "network"
          "memory"
          "cpu"
          "backlight"
          "battery"
          "battery#bat2"
          "tray"
        ];

        # Module configuration: Left
        "custom/spacer" = { format = "❄️"; };
        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = false;
          active-only = false;
          format = "<span><b>{icon}</b></span>";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            urgent = " ";
          };
        };
        "wlr/taskbar" = {
          format = "{icon}";
          icon-size = 13;
          tooltip = true;
          tooltip-format = "{title}";
          active-first = false;
          on-click = "activate";
          on-click-middle = "close";
        };
        "hyprland/window" = {
          max-length = 50;
          format = "<i>{title}</i>";
          separate-outputs = true;
          icon = true;
          icon-size = 13;
        };

        # Module configuration: Center
        clock = {
          format = "<b> {:%a %b %d  %I:%M %p}</b>";
          tooltip-format = ''
            <big>{:%Y %B}</big>
            <tt><small>{calendar}</small></tt>'';
          format-alt = "<b>{:%H:%M %Y-%m-%d}</b>";
        };

        # Module configuration: Right
        pulseaudio = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon}  {format_source}";
          format-bluetooth-muted = " {icon}   {format_source}";
          format-muted = "  {format_source}";
          format-source = " {volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "󰋎";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
        network = {
          format-wifi = "{essid} ({signalStrength}%)  ";
          format-ethernet = "{ipaddr}/{cidr}  ";
          tooltip-format = "{ifname} via {gwaddr}  ";
          format-linked = "{ifname} (No IP)  ";
          format-disconnected = "Disconnected ⚠ ";
          format-alt = "{ifname}: {ipaddr}/{cidr} ";
        };
        cpu = {
          format = "{usage}%  ";
          tooltip = false;
        };
        memory = { format = "{}%  "; };
        backlight = {
          format = "{percent}% {icon}";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
        };
        battery = {
          states = {
            # good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon} ";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        "battery#bat2" = { bat = "BAT2"; };
        tray = {
          icon-size = 18;
          spacing = 10;
        };
        "custom/toggl" = {
          format = "{}";
          exec = "$HOME/.config/waybar/toggl_status.py";
          interval = 10;
          on-click = "toggl stop";
        };
      };
    };
  };
}
