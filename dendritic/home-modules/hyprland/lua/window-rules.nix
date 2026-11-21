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

  utilityTitle = "(clipse|bluetui|nmtui|wiremix|window-switcher)";
  btopTitle = "(btop)";

  floatRule =
    name: match: size:
    mkRule {
      inherit name match size;
      float = true;
      center = true;
      stay_focused = true;
      pin = true;
    };

  # Envy has no per-monitor size need, so it matches on title alone. A workspace
  # match makes the rule dynamic: Hyprland re-applies it on every workspace
  # change, so a floating window loses its float when it moves.
  envyFloatRules = [
    (floatRule "utils-float" { title = utilityTitle; } (vec2 1200 800))
    (floatRule "btop-float" { title = btopTitle; } (vec2 1600 900))
  ];

  # Desky needs a per-monitor size: the rotated HDMI-A-5 panel is 1080 px wide,
  # so a 1200 px window does not fit there. Only a workspace match selects the
  # monitor, so these rules stay dynamic on Desky.
  deskyFloatRules = [
    (floatRule "utils-primary" { workspace = primaryWorkspacesMatcher; title = utilityTitle; } (vec2 1200 800))
    (floatRule "utils-game" { workspace = "name:Game"; title = utilityTitle; } (vec2 1200 800))
    (floatRule "btop-primary" { workspace = primaryWorkspacesMatcher; title = btopTitle; } (vec2 1600 900))
    (floatRule "btop-game" { workspace = "name:Game"; title = btopTitle; } (vec2 1600 900))
    (floatRule "utils-secondary" { workspace = secondaryWorkspacesMatcher; title = "(btop|clipse|bluetui|nmtui|wiremix)"; } (vec2 1000 800))
  ];

  sharedRules = [
    (mkRule {
      name = "pip";
      match = {
        title = "^Picture-in-Picture$";
      };
      pin = true;
      float = true;
    })
    (mkRule {
      name = "android-emulator-float";
      match = {
        class = "(Emulator)";
      };
      float = true;
      center = true;
      pin = true;
    })
    (mkRule {
      name = "focus-cursor-zen";
      match = {
        class = "(zen.*)";
      };
      focus_on_activate = true;
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
      name = "android-emulator-ws6";
      match = {
        class = "(Emulator)";
      };
      workspace = lib.head secondaryWorkspaces;
    })
    (mkRule {
      name = "vesktop-secondary";
      match = {
        class = "(vesktop)";
      };
      workspace = lib.head secondaryWorkspaces;
    })
  ];

  floatRules = if hostname == "GoofyDesky" then deskyFloatRules else envyFloatRules;
in
lib.concatStringsSep "\n" (
  floatRules
  ++ sharedRules
  ++ lib.optionals (hostname == "GoofyDesky") deskyRules
)
