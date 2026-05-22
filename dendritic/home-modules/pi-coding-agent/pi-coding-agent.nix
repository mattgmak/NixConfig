{ inputs, lib, ... }:
{
  flake.homeModules.pi-coding-agent =
    { config, pkgs, ... }:
    let
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      piAgentRoot = "${repoRoot}/home-modules/pi-coding-agent";
      extensionsDir = "${piAgentRoot}/extensions";

      piNpmI = pkgs.writeShellApplication {
        name = "pi-npm-i";
        runtimeInputs = with pkgs; [ nodejs_22 ];
        text = ''
          set -euo pipefail
          EXTENSIONS=${lib.escapeShellArg extensionsDir}
          for ext in "$EXTENSIONS"/*; do
            [ -d "$ext" ] || continue
            pkg="$ext/package.json"
            [ -f "$pkg" ] || continue
            if node -e "
              const fs = require('node:fs');
              const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
              process.exit(Object.keys(p.dependencies || {}).length > 0 ? 0 : 1);
            " "$pkg"; then
              echo "pi-npm-i: $(basename "$ext")"
              (cd "$ext" && npm i --prod "$@")
            fi
          done
        '';
      };
    in
    {
      imports = [ inputs.coding-agents.homeManagerModules.default ];

      coding-agents = {
        skillsDir = lib.mkDefault "${repoRoot}/skills";
        pi-coding-agent = {
          enable = lib.mkDefault true;
          extensionsDir = lib.mkDefault "${piAgentRoot}/extensions";
          promptsDir = lib.mkDefault "${piAgentRoot}/prompts";
        };
      };

      home.packages = with pkgs; [
        nodejs_22
        ffmpeg
        uv
        bun
        piNpmI
      ];

      home.file.".pi/agent/themes".source = config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/themes";
      home.file.".pi/agent/models.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/models.json";
      home.file.".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/mcp.json";
    };
}
