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
  primaryWorkspacesMatcher = "r[${lib.head primaryWorkspaces}-${lib.last primaryWorkspaces}]";
  secondaryWorkspacesMatcher = "r[${lib.head secondaryWorkspaces}-${lib.last secondaryWorkspaces}]";

  luaBool = b: if b then "true" else "false";

  vec2 = w: h: "{ ${toString w}, ${toString h} }";

  luaValue =
    v:
    if lib.isBool v then
      luaBool v
    else if lib.isInt v then
      toString v
    else if lib.isString v && lib.hasPrefix "{" v then
      v
    else
      "\"${v}\"";

  mkRule =
    attrs:
    let
      name = attrs.name;
      match = attrs.match or { };
      effects = lib.removeAttrs attrs [
        "name"
        "match"
      ];
      matchLua =
        if match == { } then
          ""
        else
          "match = { "
          + lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${luaValue v}") match)
          + " }, ";
      effectsLua = lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${luaValue v}") effects);
    in
    "hl.window_rule({ name = \"${name}\", ${matchLua}${effectsLua} })";

  utilityFloatRule =
    name: matchExtra:
    mkRule {
      inherit name;
      match = matchExtra;
      float = true;
      size = vec2 1200 800;
      center = true;
      stay_focused = true;
      pin = true;
    };

  btopFloatRule =
    name: matchExtra:
    mkRule {
      inherit name;
      match = matchExtra;
      float = true;
      size = vec2 1600 900;
      center = true;
      stay_focused = true;
      pin = true;
    };

  sharedRules = [
    (utilityFloatRule "utils-primary" {
      workspace = primaryWorkspacesMatcher;
      title = "(clipse|bluetui|nmtui|wiremix|window-switcher)";
    })
    (utilityFloatRule "utils-game" {
      workspace = "name:Game";
      title = "(clipse|bluetui|nmtui|wiremix|window-switcher)";
    })
    (btopFloatRule "btop-primary" {
      workspace = primaryWorkspacesMatcher;
      title = "(btop)";
    })
    (btopFloatRule "btop-game" {
      workspace = "name:Game";
      title = "(btop)";
    })
    (mkRule {
      name = "pip";
      match = {
        title = "^Picture-in-Picture$";
      };
      pin = true;
      float = true;
    })
    (mkRule {
      name = "floating-terminal";
      match = {
        title = "(floating-terminal)";
      };
      float = true;
      pin = true;
      center = true;
      stay_focused = true;
      size = vec2 1200 800;
    })
    (mkRule {
      name = "focus-cursor-zen";
      match = {
        class = "([Cc]ursor|zen.*)";
      };
      focus_on_activate = true;
    })
    (mkRule {
      name = "center-floating-cursor";
      match = {
        class = "([Cc]ursor)";
        float = true;
      };
      center = true;
    })
    (mkRule {
      name = "no-anim-switcher";
      match = {
        title = "(window-switcher|clipse)";
      };
      no_anim = true;
    })
    (mkRule {
      name = "ueberzug";
      match = {
        class = "^ueberzug.*";
      };
      no_anim = true;
      border_size = 0;
      float = true;
      no_focus = true;
      no_shadow = true;
      rounding = 0;
    })
  ];

  deskyRules = [
    (mkRule {
      name = "pip-secondary";
      match = {
        title = "^Picture-in-Picture$";
      };
      monitor = deskyMonitors.secondary;
      no_initial_focus = true;
      center = true;
      size = vec2 986 555;
    })
    (mkRule {
      name = "games-to-game-workspace";
      match = {
        class = "(org.prismlauncher.PrismLauncher|steam|Minecraft.*|cs2|osu!|steam_app_.*)";
      };
      workspace = "name:Game";
    })
    (mkRule {
      name = "games-immediate";
      match = {
        class = "(cs2|steam_app_.*)";
      };
      immediate = true;
    })
    (mkRule {
      name = "steam-fullscreen";
      match = {
        class = "(steam_app_.*)";
      };
      fullscreen = true;
    })
    (mkRule {
      name = "utils-secondary";
      match = {
        workspace = secondaryWorkspacesMatcher;
        title = "(btop|clipse|bluetui|nmtui|wiremix)";
      };
      float = true;
      size = vec2 1000 800;
      center = true;
      stay_focused = true;
      pin = true;
    })
    (mkRule {
      name = "vesktop-secondary";
      match = {
        class = "(vesktop)";
      };
      workspace = lib.head secondaryWorkspaces;
    })
  ];
in
lib.concatStringsSep "\n" (sharedRules ++ lib.optionals (hostname == "GoofyDesky") deskyRules)
