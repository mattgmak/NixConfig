# pi for the hermes user. The agent user keeps its pi in its own home-manager
# profile, and /home/agent is 0700, so hermes cannot read that profile or its
# agent dir. This package builds a second pi from the same compiled derivation
# and points it at a hermes-owned agent dir clamped to the ramsay provider.
#
# pi-interactive-subagents is absent on purpose. A print-mode parent exits
# before a subagent result lands, so Hermes keeps the delegation role and one pi
# run does one task.
{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      piCompiled = self.packages.${system}.piCompiled;
      piModule = ../home-modules/pi-coding-agent;
      compiledExtensionsDir = "${piCompiled}/share/pibolt-home/.pi/agent/extensions";

      provider = "ramsay";
      modelId = "halogen-flash-next-signal-abliterated";
      model = "${provider}/${modelId}";

      modelsJson = builtins.fromJSON (builtins.readFile (piModule + "/models.json"));
      modelEntry = pkgs.lib.findFirst (
        m: (m.id or "") == modelId
      ) null modelsJson.providers.${provider}.models;

      settingsJson = builtins.fromJSON (builtins.readFile (piModule + "/settings.json"));
      settings = pkgs.writeText "pi-local-hermes-settings.json" (
        builtins.toJSON (
          settingsJson
          // {
            defaultProvider = provider;
            defaultModel = model;
            enabledModels = [ "ramsay/*" ];
            modelThinkingLevels = pkgs.lib.filterAttrs (
              key: _: pkgs.lib.hasPrefix "ramsay/" key
            ) settingsJson.modelThinkingLevels;
          }
        )
      );

      # pi-autoname reads its own model field and ignores enabledModels, so it
      # needs the loadout copy.
      autoname = pkgs.writeText "pi-local-hermes-pi-autoname.json" (
        builtins.toJSON (
          (
            builtins.fromJSON (builtins.readFile (piModule + "/extensions/pi-autoname/pi-autoname.json"))
          )
          // {
            inherit model;
            fallbackModels = [ ];
          }
        )
      );

      modelRef =
        thinking: {
          inherit provider;
          id = modelId;
          inherit thinking;
          cooldownHours = 2;
          contextWindow = modelEntry.contextWindow;
        };
      blackholeConfig = pkgs.writeText "pi-local-hermes-pi-blackhole-config.json" (
        builtins.toJSON (
          (
            builtins.fromJSON (
              builtins.readFile (piModule + "/extensions/pi-blackhole/pi-blackhole-config.json")
            )
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

      # Extension loaders come from the compiled tree. The shell lists them at
      # build time, so a pi bump updates the set without an edit here.
      extensions = pkgs.runCommand "pi-local-hermes-extensions" { } ''
        mkdir -p $out
        for d in ${compiledExtensionsDir}/*; do
          name="$(basename "$d")"
          if [ "$name" != "pi-interactive-subagents" ]; then
            ln -s "$d" "$out/$name"
          fi
        done
      '';

      # bin/pi plus the agent dir mirrored into $HOME/.pi/agent. The mirror holds
      # symlinks only, so pi still writes sessions and cache in a writable dir.
      # extensions gets real directories with linked files: an extension that
      # writes state next to its loader hits a read-only store otherwise.
      # MCP stays off: the agent's servers need OAuth keys this user has none of.
      piLocalHermes = pkgs.writeShellApplication {
        name = "pi-local";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          dir="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
          mkdir -p "$dir"
          ln -sfn ${settings} "$dir/settings.json"
          ln -sfn ${piModule + "/models.json"} "$dir/models.json"
          ln -sfn ${autoname} "$dir/pi-autoname.json"
          mkdir -p "$dir/pi-blackhole"
          ln -sfn ${blackholeConfig} "$dir/pi-blackhole/pi-blackhole-config.json"
          ln -sfn ${piModule + "/keybindings.json"} "$dir/keybindings.json"
          ln -sfn ${piModule + "/web-search.json"} "$dir/web-search.json"
          ln -sfn ${piModule + "/themes"} "$dir/themes"
          ln -sfn ${piModule + "/prompts"} "$dir/prompts"
          mkdir -p "$dir/extensions"
          for entry in ${extensions}/*; do
            name="$(basename "$entry")"
            if [ -d "$entry" ]; then
              mkdir -p "$dir/extensions/$name"
              for file in "$entry"/*; do
                ln -sfn "$file" "$dir/extensions/$name/$(basename "$file")"
              done
            else
              ln -sfn "$entry" "$dir/extensions/$name"
            fi
          done
          # bin/pi forces `exec -a pi`, so the wrapper execs the app and repeats the
          # env bin/pi sets. The name keeps tmux, ps, and agent-sesh on pi-local.
          export PIBOLT_NPM=1
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          export PI_TELEMETRY=0
          export ENGRAM_URL=http://127.0.0.1:7437
          export PI_PACKAGE_DIR="${piCompiled}/libexec/pi"
          export AGENT_SESH_AGENT_NAME=pi-local
          exec -a pi-local "${piCompiled}/libexec/pi/pi" --no-mcp "$@"
        '';
      };
    in
    {
      packages.piLocalHermes = piLocalHermes;
    };
}
