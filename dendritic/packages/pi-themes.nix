# Every theme pi can load: the vendored JSONs of
# home-modules/pi-coding-agent/themes plus the stylix theme generated from the
# repo palette. The home-manager module and the hermes package both link this
# farm, so every agent dir gets the same set. The farm cannot live in the
# home-manager module: a package there is invisible, and `stylix.json` is
# generated, so it never exists in the checkout.
{
  inputs,
  self,
  lib,
  ...
}:
let
  # Pi theme JSON for the stylix palette. `colors` takes a stylix palette
  # (config.lib.stylix.colors) or a base16.nix scheme.
  mkPiStylixTheme =
    colors:
    let
      c = colors.withHashtag;
      hex = name: c.${name} or "#000000";

      baseNames = [
        "base00"
        "base01"
        "base02"
        "base03"
        "base04"
        "base05"
        "base06"
        "base07"
        "base08"
        "base09"
        "base0A"
        "base0B"
        "base0C"
        "base0D"
        "base0E"
        "base0F"
      ];

      vars = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = hex name;
        }) baseNames
      );

      theme = {
        "$schema" =
          "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
        name = "stylix";
        inherit vars;
        colors = {
          accent = "base0E";
          border = "base0D";
          borderAccent = "base0C";
          borderMuted = "base02";
          success = "base0B";
          error = "base08";
          warning = "base0A";
          muted = "base04";
          dim = "base03";
          text = "base05";
          thinkingText = "base04";

          selectedBg = "base02";
          userMessageBg = "base02";
          userMessageText = "base05";
          customMessageBg = "base01";
          customMessageText = "base05";
          customMessageLabel = "base0E";
          toolPendingBg = "base01";
          toolSuccessBg = "base02";
          toolErrorBg = "base01";
          toolTitle = "base05";
          toolOutput = "base04";

          mdHeading = "base09";
          mdLink = "base0D";
          mdLinkUrl = "base04";
          mdCode = "base0C";
          mdCodeBlock = "base0B";
          mdCodeBlockBorder = "base03";
          mdQuote = "base04";
          mdQuoteBorder = "base03";
          mdHr = "base03";
          mdListBullet = "base0E";

          toolDiffAdded = "base0B";
          toolDiffRemoved = "base08";
          toolDiffContext = "base04";

          syntaxComment = "base04";
          syntaxKeyword = "base0E";
          syntaxFunction = "base0D";
          syntaxVariable = "base05";
          syntaxString = "base0B";
          syntaxNumber = "base09";
          syntaxType = "base0A";
          syntaxOperator = "base0C";
          syntaxPunctuation = "base06";

          thinkingOff = "base02";
          thinkingMinimal = "base03";
          thinkingLow = "base0D";
          thinkingMedium = "base0C";
          thinkingHigh = "base0E";
          thinkingXhigh = "base0F";

          bashMode = "base0B";
        };
        export = {
          pageBg = "base00";
          cardBg = "base01";
          infoBg = "base02";
        };
      };
    in
    builtins.toJSON theme;

  # Colour map for the pi-powerline-footer extension, same palette.
  mkPiPowerlineTheme =
    colors:
    let
      c = colors.withHashtag;
      hex = name: c.${name} or "#000000";

      theme = {
        colors = {
          model = hex "base0E";
          shellMode = "accent";
          path = hex "base0C";
          gitDirty = "warning";
          gitClean = "success";
          thinking = "thinkingOff";
          thinkingMinimal = "thinkingMinimal";
          thinkingLow = "thinkingLow";
          thinkingMedium = "thinkingMedium";
          context = "dim";
          contextWarn = "warning";
          contextError = "error";
          cost = "text";
          tokens = "muted";
          separator = "dim";
          border = "borderMuted";
        };
        icons = {
          auto = "↯";
          warning = "";
        };
      };
    in
    builtins.toJSON theme;
in
{
  flake.piThemes = {
    inherit mkPiStylixTheme mkPiPowerlineTheme;
  };

  perSystem =
    { pkgs, system, ... }:
    let
      themesDir = ../home-modules/pi-coding-agent/themes;
      # The one palette of the repo, read from the same source as every host.
      scheme = (self.stylixCommon { inherit lib pkgs; }).stylix.base16Scheme;
      base16Lib = inputs.stylix.inputs.base16.lib { inherit lib pkgs; };
      colors = (base16Lib.mkSchemeAttrs scheme).override { };
    in
    {
      packages.piAgentThemes = pkgs.linkFarm "pi-agent-themes" (
        (
          map (name: {
            inherit name;
            path = themesDir + "/${name}";
          }) (builtins.attrNames (builtins.readDir themesDir))
        )
        ++ [
          {
            name = "stylix.json";
            path = pkgs.writeText "pi-stylix-theme.json" (mkPiStylixTheme colors);
          }
        ]
      );
    };
}
