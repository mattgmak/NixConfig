# Seed LearnHarness provider config (ramsay thinkingcap endpoint, keyless) on
# first activation; the app owns auth.json/settings.json afterwards.
{ ... }:
{
  flake.homeModules.learnharness-seed =
    { lib, config, ... }:
    let
      seed = ./learnharness-seed;
      userData = "${config.home.homeDirectory}/LearnHarness";
    in
    {
      home.activation.learnharnessSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${userData}/data
        [ -e ${userData}/auth.json ] || install -m 600 ${seed}/auth.json ${userData}/auth.json
        [ -e ${userData}/data/settings.json ] || install -m 644 ${seed}/data/settings.json ${userData}/data/settings.json
      '';
    };
}
