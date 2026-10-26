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
      autoExtDepsInstall = config.piCodingAgent.autoExtDepsInstall;
      nixConfigRoot = "${config.home.homeDirectory}/NixConfig";
      repoRoot = "${nixConfigRoot}/dendritic";
      piAgentRoot = "${repoRoot}/home-modules/pi-coding-agent";
      extensionsDir = "${piAgentRoot}/extensions";
      vendorRoot = "${nixConfigRoot}/vendor";
      leanCtx = self.packages.${system}.lean-ctx;

      # mcp.json is the single source of the mcp-nixos pin. The warm activation
      # below reads the flake URL from it, so a rev bump is one edit.
      mcpConfig = builtins.fromJSON (builtins.readFile ./mcp.json);
      mcpNixosFlake = lib.findFirst (arg: lib.hasPrefix "github:" arg) null (
        mcpConfig.mcpServers.nixos.args or [ ]
      );

      piCompiled = self.packages.${system}.piCompiled;
      piStock = self.packages.${system}.pi;

      # The compiled binary uses its compiled copy of an extension only while the copy it
      # finds is the one the compiler recorded, and those recorded paths are absolute,
      # inside the package. A copy or the repo checkout misses that lookup, and rpiv-todo
      # and rpiv-ask-user-question have no fallback, so they fail startup. So: a symlink
      # into the store tree for every name the package compiled, a repo symlink for the
      # loaders it left out (those load from files, as before). The split is read from the
      # package, so a new compiled extension needs no edit here.
      compiledExtensionsDir = "${piCompiled}/share/pibolt-home/.pi/agent/extensions";
      compiledExtensions = piCompiled.extensions;

      # Loader folders and loader symlinks (pi-agent-sesh resolves into vendor); `vendor`
      # is added below with its own target, and the smoke-test script is not a loader.
      repoExtensionNames = builtins.attrNames (
        lib.filterAttrs (
          name: type: name != "vendor" && (type == "directory" || type == "symlink")
        ) (builtins.readDir ./extensions)
      );

      # These extensions write inside their own folder at run time: pi-permission-system
      # creates logs/ on the first log line. A symlinked folder cannot take that write,
      # because it resolves to the store or to the repo. So each name here gets a real
      # directory in the agent dir, with every file linked to its source.
      writableExtensions = [
        "pi-permission-system" # permission audit trail: writes logs/ beside its config
        "pi-lean-ctx" # MCP schema cache: writes mcp-schema-cache.json beside its config
      ];
      writablePresent = lib.filter (name: lib.elem name (compiledExtensions ++ repoExtensionNames)) writableExtensions;
      writableSource =
        name:
        if lib.elem name compiledExtensions then
          "${compiledExtensionsDir}/${name}"
        else
          "${extensionsDir}/${name}";

      # Names inside a writable extension, listed at eval time. The runCommand only makes
      # links, so a build sandbox never has to read the repo.
      writableList =
        name: sub:
        builtins.readDir (
          if lib.elem name compiledExtensions then
            "${compiledExtensionsDir}/${name}${sub}"
          else
            ./extensions + "/${name}${sub}"
        );

      # A real directory, so a sibling like logs/ can appear, with each file linked to its
      # source, so code edits take effect at once.
      writableMirror =
        name:
        let
          src = writableSource name;
          top = writableList name "";
          link = entry:
            if top.${entry} == "directory" then
              ''
                mkdir -p $out/${name}/${entry}
                ${lib.concatMapStrings (sub: ''
                  ln -s ${src}/${entry}/${sub} $out/${name}/${entry}/${sub}
                '') (builtins.attrNames (writableList name "/${entry}"))}
              ''
            else
              ''
                ln -s ${src}/${entry} $out/${name}/${entry}
              '';
        in
        lib.concatMapStrings link (builtins.attrNames top);

      piExtensionsDir = pkgs.runCommand "pi-agent-extensions" { } ''
        mkdir -p $out
        ${lib.concatMapStrings (name: ''
          mkdir -p $out/${name}
          ${writableMirror name}
        '') writablePresent}
        ${lib.concatMapStrings (name: ''
          ln -s ${compiledExtensionsDir}/${name} $out/${name}
        '') (lib.subtractLists writablePresent compiledExtensions)}
        ${lib.concatMapStrings (name: ''
          ln -s ${extensionsDir}/${name} $out/${name}
        '') (lib.subtractLists (compiledExtensions ++ writablePresent) repoExtensionNames)}
        ln -s ${vendorRoot} $out/vendor
      '';

      # Same guard as the overlay in overlays.nix: only x86_64-linux runs the compiled
      # binary, so only there does the agent dir point at the store tree. Elsewhere the
      # plain binary keeps reading the repo tree.
      piAgentExtensions =
        if system == "x86_64-linux" then
          piExtensionsDir
        else
          config.lib.file.mkOutOfStoreSymlink extensionsDir;

      agentDevDir = "${config.home.homeDirectory}/.pi/agent-dev";
      agentDevShared = [
        "AGENTS.md"
        "auth.json"
        "agents"
        "keybindings.json"
        "mcp.json"
        "models.json"
        "pi-blackhole"
        "prompts"
        "settings.json"
        "skills"
        "themes"
        "web-search.json"
      ];

      # The fallback command. Extensions come from the repo tree, so every loader runs
      # from files; PI_CODING_AGENT_DIR keeps it off the default agent dir.
      piStockWrapper = pkgs.writeShellApplication {
        name = "pi-stock";
        text = ''
          export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent-dev}"
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          exec ${piStock}/bin/pi "$@"
        '';
      };

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

      crawl4aiPort = 11235;
      crawl4aiImage = "docker.io/unclecode/crawl4ai:latest";
      crawl4aiApiToken = builtins.substring 0 64 (
        builtins.hashString "sha256" "pi-crawl4ai-${config.home.homeDirectory}"
      );

      searxngPort = 8888;
      # Pin the multi-arch OCI *index* digest, not a platform sub-manifest: podman
      # then selects the native image. Pinning the amd64 sub-manifest digest made
      # arm64 hosts run the image under qemu, which segfaults.
      searxngImage = "docker.io/searxng/searxng:2026.9.22-2ed96e6fc@sha256:f6f67c89efdac7b1bd4805703764ecaa9d0777b86a101b86cae4f1563de4d627";
      searxngSecretKey = builtins.substring 0 64 (
        builtins.hashString "sha256" "pi-searxng-${config.home.homeDirectory}"
      );
      searxngSettingsFile = "${config.home.homeDirectory}/.local/share/pi-searxng/settings.yml";
      searxngSettingsYaml = ''
        use_default_settings: true
        general:
          debug: false
          instance_name: pi-searxng
        server:
          secret_key: ${searxngSecretKey}
          limiter: false
          public_instance: false
          image_proxy: false
          method: GET
        search:
          formats:
            - html
            - json
          autocomplete: ""
      '';

      piExtDepsInstall = pkgs.writeShellApplication {
        name = "pi-ext-deps-install";
        runtimeInputs = with pkgs; [
          git
          node-bin
          pnpm
          bun
          gleam
          coreutils
          findutils
        ];
        text = ''
          set -euo pipefail
          EXTENSIONS=${lib.escapeShellArg extensionsDir}
          VENDOR_ROOT=${lib.escapeShellArg vendorRoot}
          STAMP_ROOT="$HOME/.local/state/pi-ext-deps-stamps"
          NODE_V=$(node --version)
          NPM_V=$(npm --version)

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
                echo "pi-ext-deps-install: remove untracked files in vendor/$name"
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

          # Aggregate stamp in pi-ext-deps-install-if-stale gates the whole tree.
          # This finer gate skips one dir when the tree changed elsewhere. Key is a
          # path hash: queue_parallel runs dirs in parallel, one stamp per dir.
          fingerprint_dir() {
            local dir="$1"
            {
              printf 'node %s\n' "$NODE_V"
              printf 'npm %s\n' "$NPM_V"
              find "$dir" -name node_modules -prune -o -type f \
                \( -name package.json -o -name package-lock.json \
                -o -name pnpm-lock.yaml -o -name bun.lock \
                -o -name bun.lockb -o -name Cargo.lock \) \
                -printf '%p %T@ %s\n'
            } | sort | sha256sum | cut -d' ' -f1
          }

          gated_install() {
            local dir="$1"
            local label="$2"
            shift 2
            local stamp
            stamp="$STAMP_ROOT/$(printf '%s' "$dir" | sha256sum | cut -c1-16)"
            if [ -d "$dir" ]; then
              if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$(fingerprint_dir "$dir")" ]; then
                echo "pi-ext-deps-install: skip $label"
                return 0
              fi
            fi
            if ! "$@"; then
              # stamp records post-install state; none on failure so the dir retries
              rm -f "$stamp"
              return 1
            fi
            [ -d "$dir" ] || return 0
            fingerprint_dir "$dir" > "$stamp"
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
            echo "pi-ext-deps-install: $label"
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
            echo "pi-ext-deps-install: vendor/gotgenes/pi-packages (pnpm install --frozen-lockfile)"
            (cd "$dir" && pnpm install --frozen-lockfile)
          }

          install_fgladisch_pi() {
            local dir="$VENDOR_ROOT/fgladisch/pi-extensions"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-ext-deps-install: vendor/fgladisch/pi-extensions (npm ci)"
            (cd "$dir" && npm ci --omit=dev --ignore-scripts)
          }

          install_lean_ctx_pi() {
            local dir="$VENDOR_ROOT/mattgmak/lean-ctx/packages/pi-lean-ctx"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-ext-deps-install: vendor/mattgmak/lean-ctx/packages/pi-lean-ctx (npm ci + build:vendor)"
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
              echo "pi-ext-deps-install: discard tracked changes in vendor/$label"
              git -C "$dir" restore .
            fi
          }

          install_pi_cursor_sdk() {
            local dir="$VENDOR_ROOT/fitchmultz/pi-cursor-sdk"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-ext-deps-install: vendor/fitchmultz/pi-cursor-sdk (npm ci --ignore-scripts; build dist/)"
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
              echo "pi-ext-deps-install: pi-cursor-sdk dist/index.js missing after build" >&2
              exit 1
            fi
            # pi-bolt is a compiled bun binary; its extension loader resolves extension
            # deps itself and fails on this package's bare node_modules deps
            # (@cursor/sdk, @bufbuild/protobuf) at runtime. Inline them for that host;
            # node hosts keep using dist/.
            (cd "$dir" && bun build dist/index.js \
              --target=bun --format=esm \
              --outfile="$EXTENSIONS/pi-cursor-sdk/pi-bolt-bundle.js" \
              --external '@earendil-works/*' \
              --external '@mariozechner/*' \
              --external 'typebox*' \
              --external '@sinclair/typebox*' \
              --external '*.node')
            restore_vendor_tracked_changes "$dir" "pi-cursor-sdk"
          }

          install_pi_agent_browser_native() {
            local dir="$VENDOR_ROOT/fitchmultz/pi-agent-browser-native"
            [ -f "$dir/package.json" ] || return 0
            echo "pi-ext-deps-install: vendor/fitchmultz/pi-agent-browser-native (npm ci --ignore-scripts; build dist/)"
            if [ -f "$dir/package-lock.json" ]; then
              (cd "$dir" && npm ci --ignore-scripts)
            else
              (cd "$dir" && npm install --omit=dev --no-package-lock --ignore-scripts)
            fi
            (cd "$dir" && node scripts/build.mjs)
            (cd "$dir" && npm prune --omit=dev --ignore-scripts)
            if [ ! -f "$dir/dist/extensions/agent-browser/index.js" ]; then
              echo "pi-ext-deps-install: pi-agent-browser-native dist/extensions/agent-browser/index.js missing after build" >&2
              exit 1
            fi
            restore_vendor_tracked_changes "$dir" "pi-agent-browser-native"
          }

          install_agent_ste() {
            local dir="$VENDOR_ROOT/ctotheameron/agent-ste"
            [ -f "$dir/scripts/build-dist.sh" ] || return 0
            echo "pi-ext-deps-install: vendor/ctotheameron/agent-ste (gleam build --target javascript; build dist/)"
            (cd "$dir" && ./scripts/build-dist.sh)
            if [ ! -f "$dir/dist/ste/ste.mjs" ]; then
              echo "pi-ext-deps-install: agent-ste dist/ste/ste.mjs missing after build" >&2
              exit 1
            fi
          }

          install_engram_deps() {
            local engram_pi="$VENDOR_ROOT/Gentleman-Programming/engram/plugin/pi"
            local engram_deps_dir="$VENDOR_ROOT/.engram-deps"
            [ -f "$engram_pi/package.json" ] || return 0
            echo "pi-ext-deps-install: gentle-engram deps (vendor/.engram-deps)"
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

          mkdir -p "$STAMP_ROOT"
          discard_vendor_changes
          link_powerline_theme

          for ext in "$EXTENSIONS"/*; do
            [ -d "$ext" ] || continue
            name=$(basename "$ext")
            queue_parallel gated_install "$ext" "$name" install_npm_deps "$ext" "$name"
          done

          # vendored pi extensions (vendor/<owner>/<repo>); skip repos with
          # dedicated installers (exact path — two repos are both named pi-extensions)
          # and non-extension repos (themes/skills/zen/tools)
          for vendor in "$VENDOR_ROOT"/*/*; do
            [ -d "$vendor" ] || continue
            case "$vendor" in
              "$VENDOR_ROOT/mattgmak/lean-ctx"|"$VENDOR_ROOT/gotgenes/pi-packages"|"$VENDOR_ROOT/fgladisch/pi-extensions"|"$VENDOR_ROOT/Gentleman-Programming/engram"|"$VENDOR_ROOT/fitchmultz/pi-cursor-sdk"|"$VENDOR_ROOT/fitchmultz/pi-agent-browser-native"|"$VENDOR_ROOT/ctotheameron/agent-ste") continue ;;
            esac
            case "$(basename "$vendor")" in
              pi-coding-agent|pi-ansi-themes|pi-coding-agent-catppuccin) continue ;;
              skills|zen-wireframe-2|agent-sesh|woomer|whisper-dictation) continue ;;
            esac
            queue_parallel gated_install "$vendor" "vendor/$(basename "$vendor")" install_npm_deps "$vendor" "vendor/$(basename "$vendor")"
          done

          queue_parallel gated_install "$VENDOR_ROOT/gotgenes/pi-packages" "vendor/gotgenes/pi-packages" install_pi_packages
          queue_parallel gated_install "$VENDOR_ROOT/fgladisch/pi-extensions" "vendor/fgladisch/pi-extensions" install_fgladisch_pi
          queue_parallel gated_install "$VENDOR_ROOT/mattgmak/lean-ctx/packages/pi-lean-ctx" "vendor/mattgmak/lean-ctx/packages/pi-lean-ctx" install_lean_ctx_pi
          queue_parallel gated_install "$VENDOR_ROOT/fitchmultz/pi-cursor-sdk" "vendor/fitchmultz/pi-cursor-sdk" install_pi_cursor_sdk
          queue_parallel gated_install "$VENDOR_ROOT/fitchmultz/pi-agent-browser-native" "vendor/fitchmultz/pi-agent-browser-native" install_pi_agent_browser_native
          queue_parallel gated_install "$VENDOR_ROOT/Gentleman-Programming/engram" "gentle-engram" install_engram_deps
          queue_parallel gated_install "$VENDOR_ROOT/ctotheameron/agent-ste" "vendor/ctotheameron/agent-ste" install_agent_ste

          wait_parallel

          link_extension_node_modules \
            "$EXTENSIONS/pi-permission-system" \
            "../vendor/gotgenes/pi-packages/packages/pi-permission-system/node_modules"

          discard_vendor_changes
        '';
      };

      piExtDepsInstallIfStale = pkgs.writeShellApplication {
        name = "pi-ext-deps-install-if-stale";
        runtimeInputs = with pkgs; [
          piExtDepsInstall
          git
          node-bin
          pnpm
          bun
          gleam
          coreutils
          findutils
        ];
        text = ''
          set -euo pipefail
          STATE="$HOME/.local/state"
          STAMP="$STATE/pi-ext-deps-install.stamp"
          VENDOR_ROOT=${lib.escapeShellArg vendorRoot}
          EXTENSIONS=${lib.escapeShellArg extensionsDir}

          fingerprint() {
            {
              printf 'node %s\n' "$(node --version)"
              printf 'npm %s\n' "$(npm --version)"
              for root in "$VENDOR_ROOT" "$EXTENSIONS"; do
                [ -d "$root" ] || continue
                find "$root" -name node_modules -prune -o -path '*/.engram-deps' -prune -o -type f \
                  \( -name package.json -o -name package-lock.json \
                  -o -name pnpm-lock.yaml -o -name bun.lock \
                  -o -name bun.lockb -o -name Cargo.lock \) \
                  -printf '%p %T@ %s\n'
              done | sort
            } | sha256sum | cut -d' ' -f1
          }

          mkdir -p "$STATE"
          want=$(fingerprint)
          if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$want" ]; then
            echo "pi-ext-deps-install: up to date"
            exit 0
          fi
          echo "pi-ext-deps-install: installing pi extension deps"
          # stamp records post-install state. install rewrites lockfiles.
          if pi-ext-deps-install; then
            fingerprint > "$STAMP"
          else
            echo "pi-ext-deps-install: failed (non-fatal) — run manually" >&2
            exit 1
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
      options.piCodingAgent.autoExtDepsInstall = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install pi extension dependencies when lockfiles or tool versions change. A failure is non-fatal. Use pi-ext-deps-install to install by hand.";
        };
      };

      imports = [ inputs.coding-agents.homeManagerModules.default ];

      config = {
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
            node-bin
            ffmpeg
            agent-browser
            uv
            bun
            podman
            piExtDepsInstall
            piStockWrapper
            self.packages.${system}.lean-ctx
            self.packages.${system}.engram
          ]
          ++ markdownPreviewDeps;

        systemd.user.services.crawl4ai = {
          Unit = {
            Description = "Crawl4AI fetch server for pi-web-access";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = 5;
            TimeoutStartSec = "10min";
            # --replace breaks rootless podman pasta port forwarding (host gets RST).
            ExecStartPre = [
              "-${lib.getExe pkgs.podman} pull ${crawl4aiImage}"
              "-${lib.getExe pkgs.podman} rm -f pi-crawl4ai"
            ];
            ExecStart =
              let
                hostPort = toString crawl4aiPort;
              in
              "${lib.getExe pkgs.podman} run --rm --name pi-crawl4ai --shm-size=1g -p 127.0.0.1:${hostPort}:11235 -e CRAWL4AI_API_TOKEN=${crawl4aiApiToken} ${crawl4aiImage}";
            ExecStop = "-${lib.getExe pkgs.podman} stop -t 10 pi-crawl4ai";
          };
          Install.WantedBy = [ "default.target" ];
        };

        # Granian binds :::8080 and ignores server.bind_address; loopback-only via host publish.
        systemd.user.services.searxng = {
          Unit = {
            Description = "SearXNG metasearch server for pi-web-access";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = 5;
            TimeoutStartSec = "10min";
            # --replace breaks rootless podman pasta port forwarding (host gets RST).
            ExecStartPre = [
              "-${lib.getExe pkgs.podman} pull ${searxngImage}"
              "-${lib.getExe pkgs.podman} rm -f pi-searxng"
            ];
            ExecStart =
              let
                hostPort = toString searxngPort;
              in
              "${lib.getExe pkgs.podman} run --rm --name pi-searxng -p 127.0.0.1:${hostPort}:8080 -v ${searxngSettingsFile}:/etc/searxng/settings.yml:ro ${searxngImage}";
            ExecStop = "-${lib.getExe pkgs.podman} stop -t 10 pi-searxng";
          };
          Install.WantedBy = [ "default.target" ];
        };

        home.activation.autoExtDepsInstall = lib.mkIf autoExtDepsInstall.enable (
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" "ensureNixConfig" ] ''
            ${lib.getExe piExtDepsInstallIfStale} || true
          ''
        );

        home.activation.linkPiPowerlineTheme =
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
            ''
              mkdir -p ${lib.escapeShellArg "${extensionsDir}/pi-powerline-footer"}
              ln -sfn ${lib.escapeShellArg piPowerlineThemeFile} ${lib.escapeShellArg "${extensionsDir}/pi-powerline-footer/theme.json"}
              if [ -d ${lib.escapeShellArg "${vendorRoot}/nicobailon/pi-powerline-footer"} ]; then
                ln -sfn ${lib.escapeShellArg piPowerlineThemeFile} ${lib.escapeShellArg "${vendorRoot}/nicobailon/pi-powerline-footer/theme.json"}
              fi
            '';

        # Agent dir of the pi-stock fallback. A real directory, not a store symlink: the
        # agent dir is written at run time (sessions, cache, auth.json), so a store path
        # would be read-only. Its files link back to ~/.pi/agent, so both commands share
        # settings, skills and themes.
        home.activation.piAgentDevDir = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${lib.escapeShellArg agentDevDir}
          ${lib.concatMapStrings (name: ''
            run ln -sfn ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/${name}"} ${lib.escapeShellArg "${agentDevDir}/${name}"}
          '') agentDevShared}
          run ln -sfn ${lib.escapeShellArg extensionsDir} ${lib.escapeShellArg "${agentDevDir}/extensions"}
        '';

        # Replaces the plain repo symlink that coding-agents writes. The compiled binary
        # needs the store tree; the plain one needs the repo tree. Recursive, so activation
        # makes real directories in $HOME: a writable extension can then create logs/.
        home.file.".pi/agent/extensions" = {
          source = lib.mkForce piAgentExtensions;
          recursive = true;
          force = true;
        };

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
        home.file.".pi/agent/agents".source = config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/agents";
        # SearXNG needs settings.yml with json in search.formats (else JSON API 403)
        # and use_default_settings: true (else KeyError, zero engines). Written via
        # activation (not home.file): home.file.text is a store symlink; macOS
        # podman-machine VM shares $HOME but not /nix/store, so bind-mount of the
        # symlink fails. Content still lives in a store derivation; secret_key is a
        # deterministic builtins.hashString of a constant plus config.home.homeDirectory, not a credential.
        home.activation.piSearxngSettings = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.local/share/pi-searxng"
          rm -f "$HOME/.local/share/pi-searxng/settings.yml"
          cat > "$HOME/.local/share/pi-searxng/settings.yml" <<'HEND'
          ${searxngSettingsYaml}
          HEND
          chmod 644 "$HOME/.local/share/pi-searxng/settings.yml"
        '';

        # The nixos MCP server starts as `nix run <flake>`. A cold store must fetch a
        # 143-path python closure first, and pi's connect timeout fires during that
        # copy. Warm the closure here. The out-link roots it, so `nix store gc` keeps
        # every path and the next start needs no download.
        home.activation.piMcpNixosWarm = lib.mkIf (mcpNixosFlake != null) (
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.local/state/pi-mcp-nixos"
          log="$HOME/.local/state/pi-mcp-nixos/warm.log"
          nixbin=/nix/var/nix/profiles/default/bin/nix
          [ -x "$nixbin" ] || nixbin=${pkgs.nix}/bin/nix
          "$nixbin" build --no-write-lock-file \
            --out-link "$HOME/.local/state/pi-mcp-nixos/result" \
            ${lib.escapeShellArg mcpNixosFlake} \
            >>"$log" 2>&1 || true
          tail -n 200 "$log" >"$log.trimmed" && mv "$log.trimmed" "$log"
          ''
        );

        # pi-web-access resolves web-search.json from PI_CODING_AGENT_DIR, then
        # XDG_CONFIG_HOME/pi, then ~/.pi (legacy), then ~/.pi/agent. Symlink all
        # paths so repo-managed config wins over stale /curator toggles elsewhere.
        home.file.".pi/web-search.json".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/web-search.json";
        home.file.".pi/agent/web-search.json".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/web-search.json";
        home.file.".config/pi/web-search.json".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/web-search.json";
        home.file.".config/lean-ctx/config.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/lean-ctx/config.toml";
        home.file.".pi/agent/pi-blackhole/pi-blackhole-config.json".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/extensions/pi-blackhole/pi-blackhole-config.json";
        home.file.".config/rpiv-todo/config.json".source =
          config.lib.file.mkOutOfStoreSymlink "${piAgentRoot}/rpiv-todo/config.json";

        home.sessionVariables = {
          LEAN_CTX_BIN = lib.getExe leanCtx;
          LEAN_CTX_SHELL = lib.getExe pkgs.bash;
          PI_CURSOR_ASK_QUESTION = "0";
          # ssh forwards TERM but never COLORTERM or TERM_PROGRAM, so pi's truecolor
          # hint (COLORTERM=truecolor|24bit, TERM=*-direct) and the powerline
          # extension's Nerd Font heuristic both fail and fall back remotely.
          PI_TRUE_COLOR = "1";
          POWERLINE_NERD_FONTS = "1";
          CRAWL4AI_API_TOKEN = crawl4aiApiToken;
        };
      };
    };
}
