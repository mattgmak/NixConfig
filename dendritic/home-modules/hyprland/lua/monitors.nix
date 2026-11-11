{
  hostname,
  lib,
}:
let
  deskyMonitors = {
    primary = "DP-3";
    secondary = "HDMI-A-5";
  };
  envyMonitors = {
    internal = "eDP-1";
    external = "DP-1";
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
    -- A numbered workspace takes a bare number: "name:1" is an invalid filter in Hyprland 0.57.
    hl.workspace_rule({ workspace = "1", monitor = "${deskyMonitors.primary}", layout = "monocle" })
    hl.workspace_rule({ workspace = "6", monitor = "${deskyMonitors.secondary}", layout = "scrolling", layout_opts = { direction = "down" } })
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "${index}", monitor = "${deskyMonitors.primary}" })
      '') (lib.drop 1 primaryWorkspaces)
    )}
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "${index}", monitor = "${deskyMonitors.secondary}" })
      '') (lib.drop 1 secondaryWorkspaces)
    )}
  ''
else
  ''
    hl.monitor({ output = "${envyMonitors.internal}", mode = "highres", position = "0x0", scale = 1 })
    -- EDID prefers 60 Hz. highres picks 1920x1080@74.97 here and the best mode on any other panel.
    hl.monitor({ output = "${envyMonitors.external}", mode = "highres", position = "auto-up", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto-up", scale = 1 })

    -- A numbered workspace takes a bare number: "name:1" is an invalid filter in Hyprland 0.57.
    -- The monitor field is a preference. Without DP-1, workspaces 1-5 stay on the active monitor.
    hl.workspace_rule({ workspace = "1", monitor = "${envyMonitors.external}", layout = "monocle" })
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "${index}", monitor = "${envyMonitors.external}" })
      '') (lib.drop 1 primaryWorkspaces)
    )}
    ${lib.concatStringsSep "\n" (
      map (index: ''
        hl.workspace_rule({ workspace = "${index}", monitor = "${envyMonitors.internal}" })
      '') secondaryWorkspaces
    )}
  ''
