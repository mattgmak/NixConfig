# Single source for the ramsay loadout. Exports flake.piLoadout, a function of pkgs
# in the same shape as flake.mkBuilder. dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix
# and dendritic/packages/pi-local.nix both call it, so the model set cannot drift
# between the home-manager activation and the wrapper.
{ ... }:
{
  flake.piLoadout =
    pkgs:
    let
      lib = pkgs.lib;
      provider = "ramsay";
      modelId = "halogen-flash-next-thinkingcap-abliterated";
      model = "${provider}/${modelId}";

      settingsJson = builtins.fromJSON (builtins.readFile ./settings.json);
      modelsJson = builtins.fromJSON (builtins.readFile ./models.json);

      # A wrong modelId must fail the build. The old `null` default let pi fall back
      # to the first model in the provider list, so a stale id still looked correct.
      providerModels = builtins.listToAttrs (
        map (m: { name = m.id; value = m; }) modelsJson.providers.${provider}.models
      );
      modelEntry =
        if providerModels ? ${modelId} then
          providerModels.${modelId}
        else
          throw "pi-loadout: model '${modelId}' is not in models.json provider '${provider}'";

      # Keep only the levels of models that still exist, so a dropped model leaves no
      # stale key behind.
      modelThinkingLevels = lib.filterAttrs (
        key: _value:
        let
          parts = builtins.match "([^/]+)/(.+)" key;
        in
        parts != null
        && builtins.head parts == provider
        && lib.hasAttr (builtins.elemAt parts 1) providerModels
      ) (settingsJson.modelThinkingLevels or { });

      settings = pkgs.writeText "pi-local-settings.json" (
        builtins.toJSON (
          settingsJson
          // {
            defaultProvider = provider;
            defaultModel = model;
            enabledModels = [ "${provider}/*" ];
            inherit modelThinkingLevels;
          }
        )
      );

      # pi-autoname reads its own model field and ignores enabledModels, so it needs
      # the loadout copy.
      autoname = pkgs.writeText "pi-local-pi-autoname.json" (
        builtins.toJSON (
          (
            builtins.fromJSON (builtins.readFile ./extensions/pi-autoname/pi-autoname.json)
          )
          // {
            inherit model;
            fallbackModels = [ ];
          }
        )
      );

      # pi-blackhole reads its config from <agent dir>/pi-blackhole/, so it needs the
      # loadout copy. Every model slot names the ramsay model and the fallback lists
      # go away, which keeps observation on the local server.
      modelRef =
        thinking: {
          inherit provider;
          id = modelId;
          inherit thinking;
          cooldownHours = 2;
          contextWindow = modelEntry.contextWindow;
        };
      blackholeConfig = pkgs.writeText "pi-local-pi-blackhole-config.json" (
        builtins.toJSON (
          (
            builtins.fromJSON (builtins.readFile ./extensions/pi-blackhole/pi-blackhole-config.json)
          )
          // {
            model = modelRef "low";
            observerModel = modelRef "low";
            observerFallbackModels = [ ];
            reflectorModel = modelRef "low";
            reflectorFallbackModels = [ ];
            dropperModel = modelRef "off";
            dropperFallbackModels = [ ];
          }
        )
      );
    in
    {
      inherit
        provider
        modelId
        model
        modelEntry
        settings
        autoname
        blackholeConfig
        ;
    };
}
