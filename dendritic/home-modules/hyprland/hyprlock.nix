{
  flake.homeModules.hyprlock =
    { config, hostname, ... }:
    {
      stylix.targets.hyprlock.enable = false;
      programs.hyprlock = {
        enable = true;
        settings =
          let
            mainMonitor = if hostname == "GoofyDesky" then "DP-3" else "eDP-1";
          in
          {
            general = {
              hide_cursor = true;
              ignore_empty_input = true;
              unlock_cmd = "nmcli radio wifi on";
            };
            background = [
              {
                path = "screenshot";
                blur_passes = 3;
                blur_size = 8;
                contrast = 0.8916;
                brightness = 0.8172;
                vibrancy = 0.1696;
                vibrancy_darkness = 0.0;
              }
            ];
            auth = {
              "fingerprint:enabled" = true;
            };
            label = [
              {
                monitor = mainMonitor;
                text = ''cmd[update:1000] echo "$(date +"%A, %B %d")"'';
                color = "rgba(242, 243, 244, 0.75)";
                font_size = 22;
                font_family = "IosevkaTerm Nerd Font";
                position = "0, 300";
                halign = "center";
                valign = "center";
              }
              {
                monitor = mainMonitor;
                text = ''cmd[update:1000] echo "$(date +"%-I:%M")"'';
                color = "rgba(242, 243, 244, 0.75)";
                font_size = 95;
                font_family = "IosevkaTerm Nerd Font";
                position = "0, 200";
                halign = "center";
                valign = "center";
              }
              {
                monitor = mainMonitor;
                text = "$FPRINTPROMPT";
                color = "rgba(242, 243, 244, 1)";
                font_size = 16;
                font_family = "IosevkaTerm Nerd Font";
                position = "0, -150";
                halign = "center";
                valign = "center";
              }
            ];
            input-field = [
              {
                size = "200, 50";
                halign = "center";
                valign = "center";
                position = "0, -80";
                monitor = mainMonitor;
                dots_center = true;
                fade_on_empty = false;
                hide_input = false;
                font_family = "IosevkaTerm Nerd Font";
                font_color = "rgb(205, 214, 244)";
                inner_color = "rgb(30, 30, 46)";
                outer_color = "rgb(${config.lib.stylix.colors.base0A})";
                outline_thickness = 2;
                placeholder_text = "<i>Password...</i>";
                shadow_passes = 2;
                check_color = "rgb(166, 227, 161)";
                fail_color = "rgb(243, 139, 168)";
                fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
                fail_timeout = 2000;
                fail_transition = 300;
              }
            ];
          };
      };
    };
}
