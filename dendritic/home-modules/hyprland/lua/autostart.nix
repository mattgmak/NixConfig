{
  hostname,
  pkgs,
  electronLaunchFlags,
  deskyMonitors ? null,
}:
''
  ${
    if hostname == "GoofyDesky" then
      ''
        local primary_monitor = "${deskyMonitors.primary}"
        local primary_monitor_focused = false

        local function focus_primary_monitor_center()
          local mon = hl.get_monitor(primary_monitor)
          if not mon then
            return false
          end

          hl.dispatch(hl.dsp.focus({ monitor = primary_monitor }))
          hl.dispatch(hl.dsp.cursor.move({
            x = math.floor(mon.x + mon.width / 2),
            y = math.floor(mon.y + mon.height / 2),
          }))
          primary_monitor_focused = true
          return true
        end

        hl.on("monitor.added", function(mon)
          if not primary_monitor_focused and mon.name == primary_monitor then
            focus_primary_monitor_center()
          end
        end)
      ''
    else
      ""
  }
  hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user enable --now hyprpolkitagent.service")
    hl.exec_cmd("uwsm app -- clipse -listen")
    hl.exec_cmd("uwsm app -- fcitx5 -dr")
    hl.exec_cmd("uwsm app -- fcitx5-remote -r")
    hl.exec_cmd("uwsm app -- caelestia shell -d")
    hl.exec_cmd("uwsm app -- hyprsunset --temperature 4500")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    ${
      if hostname == "GoofyDesky" then
        ''
          focus_primary_monitor_center()
          hl.exec_cmd("uwsm app -- vesktop ${electronLaunchFlags}")
        ''
      else
        ''
          hl.exec_cmd("${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh")
        ''
    }
  end)
''
