{
  hostname,
  pkgs,
  electronLaunchFlags,
}:
''
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
          hl.dispatch(hl.dsp.cursor.move({ x = 1280, y = 720 }))
          hl.exec_cmd("uwsm app -- vesktop ${electronLaunchFlags}")
        ''
      else
        ''
          hl.exec_cmd("${pkgs.bash}/bin/bash ~/.config/hypr/scripts/battery-notification.sh")
        ''
    }
  end)
''
