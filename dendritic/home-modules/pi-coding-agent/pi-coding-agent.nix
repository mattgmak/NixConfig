{
  inputs,
  self,
  lib,
  ...
}:
{
  flake.homeModules.pi-coding-agent =
    { config, pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      piAgentRoot = "${repoRoot}/home-modules/pi-coding-agent";
      extensionsDir = "${piAgentRoot}/extensions";

      piNpmI = pkgs.writeShellApplication {
        name = "pi-npm-i";
        runtimeInputs = with pkgs; [
          nodejs_22
          pnpm
        ];
        text = ''
          set -euo pipefail
          EXTENSIONS=${lib.escapeShellArg extensionsDir}
          for ext in "$EXTENSIONS"/*; do
            [ -d "$ext" ] || continue
            [ "$(basename "$ext")" = "vendor" ] && continue
            pkg="$ext/package.json"
            [ -f "$pkg" ] || continue
            kind=$(node -e "
              const fs = require('node:fs');
              const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
              if (p.workspaces != null) {
                console.log('monorepo');
              } else if (Object.keys(p.dependencies || {}).length > 0) {
                console.log('package');
              } else {
                process.exit(1);
              }
            " "$pkg") || continue
            echo "pi-npm-i: $(basename "$ext")"
            if [ -f "$ext/package-lock.json" ]; then
              if [ "$kind" = "monorepo" ]; then
                (cd "$ext" && npm ci --omit=dev --ignore-scripts "$@")
              else
                (cd "$ext" && npm ci --omit=dev "$@")
              fi
            elif [ "$kind" = "monorepo" ]; then
              (cd "$ext" && npm install --omit=dev --ignore-scripts --no-package-lock "$@")
            else
              (cd "$ext" && npm install --omit=dev --no-package-lock "$@")
            fi
          done

          PI_PACKAGES="$EXTENSIONS/vendor/pi-packages"
          if [ -f "$PI_PACKAGES/pnpm-lock.yaml" ]; then
            echo "pi-npm-i: vendor/pi-packages (pnpm install --frozen-lockfile)"
            (cd "$PI_PACKAGES" && pnpm install --frozen-lockfile)
          fi

          FGLADISCH_PI="$EXTENSIONS/vendor/fgladisch-pi-extensions"
          if [ -f "$FGLADISCH_PI/package.json" ]; then
            echo "pi-npm-i: vendor/fgladisch-pi-extensions (npm ci)"
            (cd "$FGLADISCH_PI" && npm ci --omit=dev --ignore-scripts)
          fi

          CONTEXT_MODE="$EXTENSIONS/vendor/context-mode"
          if [ -f "$CONTEXT_MODE/package.json" ]; then
            echo "pi-npm-i: vendor/context-mode (npm ci + build)"
            (cd "$CONTEXT_MODE" && npm i --omit=dev && npm ci && npm run build)
          fi

          MARKDOWN_PREVIEW="$EXTENSIONS/vendor/pi-markdown-preview"
          if [ -f "$MARKDOWN_PREVIEW/package.json" ]; then
            echo "pi-npm-i: vendor/pi-markdown-preview"
            if [ -f "$MARKDOWN_PREVIEW/package-lock.json" ]; then
              (cd "$MARKDOWN_PREVIEW" && npm ci --omit=dev)
            else
              (cd "$MARKDOWN_PREVIEW" && npm install --omit=dev --no-package-lock)
            fi
          fi
        '';
      };

      markdownPreviewDeps =
        with pkgs;
        [
          pandoc
          texliveSmall
          mermaid-cli
        ]
        ++ lib.optionals (!pkgs.stdenv.isDarwin) [ chromium ];
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

      home.packages =
        with pkgs;
        [
          nodejs_22
          ffmpeg
          uv
          bun
          piNpmI
          self.packages.${system}.colgrep
          self.packages.${system}.lean-ctx
        ]
        ++ markdownPreviewDeps;

      home.file.".pi/agent/themes".source = config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/themes";
      home.file.".pi/agent/models.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/models.json";
      home.file.".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/mcp.json";
      home.file.".pi/agent/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/settings.json";
      home.file.".pi/web-search.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/web-search.json";
    };
}
