{
  hostname,
  lib,
}:
let
  deskyMonitors = {
    primary = "DP-3";
    secondary = "HDMI-A-5";
  };
  secondaryWorkspaces = lib.map (i: toString i) (lib.range 6 10);

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

  # The rotated Desky panel is 1080 px wide, so both hosts use sizes that fit it.
  utilitySize = if hostname == "GoofyDesky" then vec2 1000 800 else vec2 1200 800;
  btopSize = if hostname == "GoofyDesky" then vec2 1000 800 else vec2 1600 900;

  # A workspace match turns a rule into a dynamic rule. Hyprland then re-applies it
  # on every workspace change, so a floating window loses its float when it moves.
  # These match on title alone, so they hold on all workspaces and on both monitors.
  floatTitled =
    name: title: size:
    mkRule {
      inherit name;
      match = { inherit title; };
      float = true;
      inherit size;
      center = true;
      stay_focused = true;
      pin = true;
    };

  utilityFloatRule = name: floatTitled name "(clipse|bluetui|nmtui|wiremix|window-switcher)" utilitySize;
  btopFloatRule = name: floatTitled name "(btop)" btopSize;

  sharedRules = [
    (utilityFloatRule "utils-float")
    (btopFloatRule "btop-float")
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
in
lib.concatStringsSep "\n" (sharedRules ++ lib.optionals (hostname == "GoofyDesky") deskyRules)
