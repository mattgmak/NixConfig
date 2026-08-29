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
      vendorRoot = "${config.home.homeDirectory}/NixConfig/vendor";
      leanCtx = self.packages.${system}.lean-ctx;

      piStaticThemes = [
        "ansi-dark.json"
        "ansi-light.json"
        "catppuccin-frappe.json"
        "catppuccin-latte.json"
        "catppuccin-macchiato.json"
        "catppuccin-mocha.json"
        "dracula.json"
      ];

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
            "$schema" = "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
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

      piStylixThemeFile = pkgs.writeTextFile {
        name = "pi-stylix-theme.json";
        text = mkPiStylixTheme config.lib.stylix.colors;
      };

      piPowerlineThemeFile = pkgs.writeTextFile {
        name = "pi-powerline-theme.json";
        text = mkPiPowerlineTheme config.lib.stylix.colors;
      };

      piNpmI = pkgs.writeShellApplication {
        name = "pi-npm-i";
        runtimeInputs = with pkgs; [
          git
          nodejs_22
          pnpm
        ];
        text = ''
          set -euo pipefail
          EXTENSIONS=${lib.escapeShellArg extensionsDir}
          VENDOR_ROOT=${lib.escapeShellArg vendorRoot}

          discard_vendor_changes() {
            for vendor in "$VENDOR_ROOT"/*/*; do
              [ -d "$vendor" ] || continue
              toplevel=$(git -C "$vendor" rev-parse --show-toplevel 2>/dev/null || true)
              [ -n "$toplevel" ] || continue
              vendor_real=$(cd "$vendor" && pwd -P)
              [ "$toplevel" = "$vendor_real" ] || continue
              status=$(git -C "$vendor" status --porcelain 2>/dev/null || true)
              [ -n "$status" ] || continue
              name=$(basename "$vendor")
              restore_vendor_tracked_changes "$vendor" "$name"
              if echo "$status" | grep -E '^(\?\?|!!)' >/dev/null; then
                echo "pi-npm-i: remove untracked files in vendor/$name"
                git -C "$vendor" clean -fd
              fi
            done
          }

          link_powerline_theme() {
            local theme=${lib.escapeShellArg piPowerlineThemeFile}
            local loader="$EXTENSIONS/pi-powerline-footer/theme.json"
            local vendor="$VENDOR_ROOT/nicobailon/pi-powerline-footer"
            mkdir -p "$(dirname "$loader")"
            ln -sfn "$theme" "$loader"
            if [ -d "$vendor" ]; then
              ln -sfn "$theme" "$vendor/theme.json"
            fi
          }

          link_extension_node_modules() {
            local ext="$1"
            local rel_vendor_nm="$2"
            local abs_vendor_nm="$ext/$rel_vendor_nm"
            if [ -d "$abs_vendor_nm" ]; then
              ln -sfn "$rel_vendor_nm" "$ext/node_modules"
            fi
          }

          install_npm_deps() {
            local dir="$1"
            local label="$2"
            local pkg="$dir/package.json"
            [ -f "$pkg" ] || return 0
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
            " "$pkg") || return 0
            echo "pi-npm-i: $label"
            if [ -f "$dir/package-lock.json" ]; then
              if [ "$kind" = "monorepo" ]; then
                (cd "$dir" && npm ci --omit=dev --ignore-scripts)
              else
                (cd "$dir" && npm ci --omit=dev)
              fi
            elif [ "$kind" = "monorepo" ]; then
              (cd "$dir" && npm install --omit=dev --ignore-scripts --no-package-lock)
            else
              (cd "$dir" && npm install --omit=dev --no-package-lock)
            fi
          }

          install_pi_packages() {
            local dir="$VENDOR_ROOT/gotgenes/pi-packages"
            [ -f "$dir/pnpm-lock.yaml" ] || return 0
            echo "pi-npm-i: vendor/gotgenes/pi-packages (pnpm install --frozen-lockfile)"
            (cd "$dir" && pnpm install --frozen-lockfile)
          }

          install_fgladisch_pi() {
            local dir="$VENDOR_ROOT/fgladisch/pi-extensions"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-npm-i: vendor/fgladisch/pi-extensions (npm ci)"
            (cd "$dir" && npm ci --omit=dev --ignore-scripts)
          }

          install_lean_ctx_pi() {
            local dir="$VENDOR_ROOT/mattgmak/lean-ctx/packages/pi-lean-ctx"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-npm-i: vendor/mattgmak/lean-ctx/packages/pi-lean-ctx (npm ci + build:vendor)"
            if [ -f "$dir/package-lock.json" ]; then
              (cd "$dir" && npm ci)
            else
              (cd "$dir" && npm install --no-package-lock)
            fi
            (cd "$dir" && npm run build:vendor)
          }

          restore_vendor_tracked_changes() {
            local dir="$1"
            local label="$2"
            git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
            status=$(git -C "$dir" status --porcelain 2>/dev/null || true)
            [ -n "$status" ] || return 0
            if echo "$status" | grep -Ev '^(\?\?|!!)' >/dev/null; then
              echo "pi-npm-i: discard tracked changes in vendor/$label"
              git -C "$dir" restore .
            fi
          }

          install_pi_cursor_sdk() {
            local dir="$VENDOR_ROOT/fitchmultz/pi-cursor-sdk"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-npm-i: vendor/fitchmultz/pi-cursor-sdk (npm ci --ignore-scripts; build dist/)"
            # prepare runs npm install --include=dev when dev deps are absent, which
            # mutates package-lock.json; build explicitly instead (same as prepare.mjs).
            if [ -f "$dir/package-lock.json" ]; then
              (cd "$dir" && npm ci --ignore-scripts)
            else
              (cd "$dir" && npm install --omit=dev --no-package-lock --ignore-scripts)
            fi
            (cd "$dir" && node scripts/build.mjs)
            (cd "$dir" && npm prune --omit=dev --ignore-scripts)
            if [ ! -f "$dir/dist/index.js" ]; then
              echo "pi-npm-i: pi-cursor-sdk dist/index.js missing after build" >&2
              exit 1
            fi
            restore_vendor_tracked_changes "$dir" "pi-cursor-sdk"
          }

          install_pi_agent_browser_native() {
            local dir="$VENDOR_ROOT/fitchmultz/pi-agent-browser-native"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-npm-i: vendor/fitchmultz/pi-agent-browser-native (npm ci --ignore-scripts; build dist/)"
            if [ -f "$dir/package-lock.json" ]; then
              (cd "$dir" && npm ci --ignore-scripts)
            else
              (cd "$dir" && npm install --omit=dev --no-package-lock --ignore-scripts)
            fi
            (cd "$dir" && node scripts/build.mjs)
            (cd "$dir" && npm prune --omit=dev --ignore-scripts)
            if [ ! -f "$dir/dist/extensions/agent-browser/index.js" ]; then
              echo "pi-npm-i: pi-agent-browser-native dist/extensions/agent-browser/index.js missing after build" >&2
              exit 1
            fi
            restore_vendor_tracked_changes "$dir" "pi-agent-browser-native"
          }

          install_engram_deps() {
            local engram_pi="$VENDOR_ROOT/Gentleman-Programming/engram/plugin/pi"
            local engram_deps_dir="$VENDOR_ROOT/.engram-deps"
            [ -f "$engram_pi/package.json" ] || return 0
            echo "pi-npm-i: gentle-engram deps (vendor/.engram-deps)"
            rm -f "$EXTENSIONS/node_modules"
            rm -rf "$engram_deps_dir"
            mkdir -p "$engram_deps_dir"
            node -e "
              const fs = require('node:fs');
              const src = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
              fs.writeFileSync(process.argv[2], JSON.stringify({
                name: 'engram-pi-deps',
                private: true,
                dependencies: src.dependencies || {},
              }, null, 2));
            " "$engram_pi/package.json" "$engram_deps_dir/package.json"
            (cd "$engram_deps_dir" && npm install --omit=dev --no-package-lock)
            ln -sfn ".engram-deps/node_modules" "$VENDOR_ROOT/node_modules"
          }

          PARALLEL_PIDS=()
          PARALLEL_FAIL=0

          queue_parallel() {
            (
              set -euo pipefail
              "$@"
            ) &
            PARALLEL_PIDS+=($!)
          }

          wait_parallel() {
            local pid
            for pid in "''${PARALLEL_PIDS[@]}"; do
              if ! wait "$pid"; then
                PARALLEL_FAIL=1
              fi
            done
            PARALLEL_PIDS=()
            if [ "$PARALLEL_FAIL" -ne 0 ]; then
              exit 1
            fi
          }

          discard_vendor_changes
          link_powerline_theme

          for ext in "$EXTENSIONS"/*; do
            [ -d "$ext" ] || continue
            queue_parallel install_npm_deps "$ext" "$(basename "$ext")"
          done

          # vendored pi extensions (vendor/<owner>/<repo>); skip repos with
          # dedicated installers (exact path — two repos are both named pi-extensions)
          # and non-extension repos (themes/skills/zen/tools)
          for vendor in "$VENDOR_ROOT"/*/*; do
            [ -d "$vendor" ] || continue
            case "$vendor" in
              "$VENDOR_ROOT/mattgmak/lean-ctx"|"$VENDOR_ROOT/gotgenes/pi-packages"|"$VENDOR_ROOT/fgladisch/pi-extensions"|"$VENDOR_ROOT/Gentleman-Programming/engram"|"$VENDOR_ROOT/fitchmultz/pi-cursor-sdk"|"$VENDOR_ROOT/fitchmultz/pi-agent-browser-native") continue ;;
            esac
            case "$(basename "$vendor")" in
              pi-coding-agent|pi-ansi-themes|pi-coding-agent-catppuccin) continue ;;
              skills|zen-wireframe-2|agent-sesh|woomer|whisper-dictation) continue ;;
            esac
            queue_parallel install_npm_deps "$vendor" "vendor/$(basename "$vendor")"
          done

          queue_parallel install_pi_packages
          queue_parallel install_fgladisch_pi
          queue_parallel install_lean_ctx_pi
          queue_parallel install_pi_cursor_sdk
          queue_parallel install_pi_agent_browser_native
          queue_parallel install_engram_deps

          wait_parallel

          if [ -d "$EXTENSIONS/pi-lens" ]; then
            link_extension_node_modules \
              "$EXTENSIONS/pi-lens" \
              "../vendor/mattgmak/pi-lens/node_modules"
          fi
          link_extension_node_modules \
            "$EXTENSIONS/pi-permission-system" \
            "../vendor/gotgenes/pi-packages/packages/pi-permission-system/node_modules"

          discard_vendor_changes
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
        agentsMdPath = lib.mkDefault "${piAgentRoot}/AGENTS.md";
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
          agent-browser
          uv
          bun
          piNpmI
          self.packages.${system}.lean-ctx
          self.packages.${system}.engram
        ]
        ++ markdownPreviewDeps;

      home.activation.linkPiPowerlineTheme = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${lib.escapeShellArg "${extensionsDir}/pi-powerline-footer"}
        ln -sfn ${lib.escapeShellArg piPowerlineThemeFile} ${lib.escapeShellArg "${extensionsDir}/pi-powerline-footer/theme.json"}
        if [ -d ${lib.escapeShellArg "${vendorRoot}/nicobailon/pi-powerline-footer"} ]; then
          ln -sfn ${lib.escapeShellArg piPowerlineThemeFile} ${lib.escapeShellArg "${vendorRoot}/nicobailon/pi-powerline-footer/theme.json"}
        fi
      '';

      home.file.".pi/agent/themes".source = pkgs.linkFarm "pi-agent-themes" (
        map (name: {
          inherit name;
          path = config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/themes/${name}";
        }) piStaticThemes
        ++ [
          {
            name = "stylix.json";
            path = piStylixThemeFile;
          }
        ]
      );
      home.file.".pi/agent/models.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/models.json";
      home.file.".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/mcp.json";
      home.file.".pi/agent/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/settings.json";
      home.file.".pi/agent/keybindings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/keybindings.json";
      home.file.".pi/agent/agents".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/agents";
      home.file.".pi/web-search.json".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/web-search.json";
      home.file.".config/lean-ctx/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/lean-ctx/config.toml";

      home.sessionVariables = {
        LEAN_CTX_BIN = lib.getExe leanCtx;
        PI_CURSOR_ASK_QUESTION = "0";
      };
    };
}
