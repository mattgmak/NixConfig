{
  hostname,
  lib,
}:
let
  deskyMonitors = {
    primary = "DP-3";
    secondary = "HDMI-A-5";
  };
  allWorkspacesIndex = lib.map (i: toString i) (lib.range 1 10);
  primaryWorkspaces = lib.take 5 allWorkspacesIndex;
  secondaryWorkspaces = lib.drop 5 allWorkspacesIndex;
in
if hostname == "GoofyDesky" then
  ''
    hl.monitor({ output = "${deskyMonitors.primary}", mode = "2560x1440@240.00Hz", position = "0x0", scale = 1 })
    hl.monitor({ output = "${deskyMonitors.secondary}", mode = "1920x1080@144.00Hz", position = "-1080x-650", scale = 1, transform = 3 })

    hl.workspace_rule({ workspace = "name:Game", monitor = "${deskyMonitors.primary}" })
    hl.workspace_rule({ workspace = "name:1", monitor = "${deskyMonitors.primary}", layout = "monocle" })
    hl.workspace_rule({ workspace = "name:6", monitor = "${deskyMonitors.secondary}", layout = "scrolling", layout_opts = { direction = "down" } })
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "name:${index}", monitor = "${deskyMonitors.primary}" })
      '') (lib.drop 1 primaryWorkspaces)
    )}
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "name:${index}", monitor = "${deskyMonitors.secondary}" })
      '') (lib.drop 1 secondaryWorkspaces)
    )}
  ''
else
  ''
    hl.monitor({ output = "eDP-1", mode = "highres", position = "0x0", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto-up", scale = 1 })
    hl.workspace_rule({ workspace = "name:1", layout = "monocle" })
  ''
