# One pi-local for every account on the host. The agent user's home-manager
# module built its own wrapper and the hermes user had pi-local-hermes, so two
# derivations drifted apart while both wrapped the same compiled pi. This file
# holds the single wrapper: the home module links it into the agent profile, and
# dendritic/nixos-modules/hermes.nix installs it for hermes.
#
# The agent dir comes from PI_CODING_AGENT_DIR or $HOME/.pi/agent-local. When
# home-manager owns that dir it already holds the links, so the mirror below
# stays off and the wrapper only exports the environment. In a home without
# home-manager the mirror builds the dir from the same pi-coding-agent files,
# clamped to the ramsay provider.
#
# pi-interactive-subagents is absent on purpose. A print-mode parent exits
# before a subagent result lands, so one pi run does one task.
{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      piCompiled = self.packages.${system}.piCompiled;
      piModule = ../home-modules/pi-coding-agent;
      compiledExtensionsDir = "${piCompiled}/share/pibolt-home/.pi/agent/extensions";

      # bin/pi reads the key from this path, and the wrapper guards it with -r so
      # an account that cannot read it simply skips the export.
      piOauthKey = "/run/agenix/pi-mcp-adapter-oauth-file-key";

      provider = "ramsay";
      modelId = "halogen-flash-next-signal-abliterated";
      model = "${provider}/${modelId}";

      modelsJson = builtins.fromJSON (builtins.readFile (piModule + "/models.json"));
      modelEntry = pkgs.lib.findFirst (
        m: (m.id or "") == modelId
      ) null modelsJson.providers.${provider}.models;

      settingsJson = builtins.fromJSON (builtins.readFile (piModule + "/settings.json"));
      settings = pkgs.writeText "pi-local-settings.json" (
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
      autoname = pkgs.writeText "pi-local-pi-autoname.json" (
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
      blackholeConfig = pkgs.writeText "pi-local-pi-blackhole-config.json" (
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
      extensions = pkgs.runCommand "pi-local-extensions" { } ''
        mkdir -p $out
        for d in ${compiledExtensionsDir}/*; do
          name="$(basename "$d")"
          if [ "$name" != "pi-interactive-subagents" ]; then
            ln -s "$d" "$out/$name"
          fi
        done
      '';

      # dendritic/skills mixes real folders with symlinks into ../../vendor, and a
      # store copy keeps those symlinks unresolved, so the vendored names break there.
      # The farm lists every skill from both sources and points each name at a folder
      # that exists in the store. Local folders win, so a forked copy shadows the
      # vendored one.
      skills =
        let
          fromDir = dir: builtins.mapAttrs (name: _: dir + "/${name}") (
            pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
          );
        in
        pkgs.linkFarm "pi-local-skills" (
          pkgs.lib.mapAttrsToList (
            name: path: { inherit name path; }
          ) ((fromDir ../../vendor/mattpocock/skills/skills/productivity) // (fromDir ../skills))
        );

      piLocal = pkgs.writeShellApplication {
        name = "pi-local";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent-local}"
          dir="$PI_CODING_AGENT_DIR"
          marker="$dir/.pi-local"
          # An agent dir that home-manager owns holds its own links. Relinking
          # there replaces them, so take a dir only when it is empty or already
          # carries the marker this wrapper leaves behind.
          if [ ! -d "$dir" ] || [ -e "$marker" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
            mkdir -p "$dir"
            : > "$marker"
            ln -sfn ${settings} "$dir/settings.json"
            ln -sfn ${piModule + "/models.json"} "$dir/models.json"
            ln -sfn ${autoname} "$dir/pi-autoname.json"
            mkdir -p "$dir/pi-blackhole"
            ln -sfn ${blackholeConfig} "$dir/pi-blackhole/pi-blackhole-config.json"
            ln -sfn ${piModule + "/keybindings.json"} "$dir/keybindings.json"
            ln -sfn ${piModule + "/web-search.json"} "$dir/web-search.json"
            ln -sfn ${self.packages.${system}.piAgentThemes} "$dir/themes"
            ln -sfn ${piModule + "/prompts"} "$dir/prompts"
            ln -sfn ${skills} "$dir/skills"
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
          fi
          # bin/pi forces `exec -a pi`, so the wrapper execs the app and repeats the
          # env bin/pi sets. The name keeps tmux, ps, and agent-sesh on pi-local.
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          export PIBOLT_NPM=1
          export PI_TELEMETRY=0
          export ENGRAM_URL=http://127.0.0.1:7437
          export PI_PACKAGE_DIR="${piCompiled}/libexec/pi"
          export AGENT_SESH_AGENT_NAME=pi-local
          key="${piOauthKey}"
          if [ -r "$key" ]; then
            PI_MCP_ADAPTER_OAUTH_FILE_KEY="$(cat "$key")"
            export PI_MCP_ADAPTER_OAUTH_FILE_KEY
          fi
          exec -a pi-local "${piCompiled}/libexec/pi/pi" "$@"
        '';
      };
    in
    {
      packages.piLocal = piLocal;
    };
}
