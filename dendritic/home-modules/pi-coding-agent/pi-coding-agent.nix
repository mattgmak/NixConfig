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
            local theme="$EXTENSIONS/pi-powerline-footer/theme.json"
            local vendor="$VENDOR_ROOT/nicobailon/pi-powerline-footer"
            if [ -f "$theme" ] && [ -d "$vendor" ]; then
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
              "$VENDOR_ROOT/mattgmak/lean-ctx"|"$VENDOR_ROOT/gotgenes/pi-packages"|"$VENDOR_ROOT/fgladisch/pi-extensions"|"$VENDOR_ROOT/Gentleman-Programming/engram"|"$VENDOR_ROOT/fitchmultz/pi-cursor-sdk") continue ;;
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
          queue_parallel install_engram_deps

          wait_parallel

          link_extension_node_modules \
            "$EXTENSIONS/pi-lens" \
            "../vendor/mattgmak/pi-lens/node_modules"
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
          uv
          bun
          piNpmI
          self.packages.${system}.lean-ctx
          self.packages.${system}.engram
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
      home.file.".config/lean-ctx/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/lean-ctx/config.toml";

      home.sessionVariables = {
        LEAN_CTX_BIN = lib.getExe leanCtx;
      };
    };
}
