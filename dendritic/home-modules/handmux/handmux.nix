{
  ...
}:
{
  flake.homeModules.handmux =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      version = "0.26.0";

      # handmux npm tarball (AGPL-3.0). Ships prebuilt dist/ (prepack builds it),
      # so no npm build step — only npm ci for deps.
      tarball = builtins.fetchurl {
        url = "https://registry.npmjs.org/handmux/-/handmux-${version}.tgz";
        sha256 = "sha256-3i3VkscC6OVXcTaPi7kK/LCU31PR6dArI1kLgaL316k=";
      };

      # fetchNpmDeps + npmConfigHook both require package-lock.json inside src —
      # the npm tarball doesn't ship one, so inject the vendored lockfile.
      # Also drop stray node_modules/ that npm ci creates in the build dir,
      # so `npm pack` (npmInstallHook) doesn't try to copy it into $out.
      src = pkgs.runCommand "handmux-${version}-src" { } ''
        mkdir -p $out
        tar -xzf ${tarball} --strip-components=1 -C $out
        cp ${./package-lock.json} $out/package-lock.json
        printf '/node_modules/\n' > $out/.gitignore
      '';

      pkg = pkgs.buildNpmPackage {
        pname = "handmux";
        inherit version src;

        # Vendored package-lock.json (generated 2026-09-04, npm 10.9.8).
        # Bump: regenerate lock (npm install --package-lock-only --ignore-scripts),
        # then nix run nixpkgs#prefetch-npm-deps -- ./package-lock.json
        # to get the new npmDepsHash.
        npmDepsHash = "sha256-PJh5LtKqk/ULCs0GKatYVqLHcDks0R6Umc1NTD0xsFI=";

        # dist/ prebuilt in tarball — nothing to compile.
        # (No "build" script exists in package.json; npmBuildScript default "build" would fail.)
        dontNpmBuild = true;

        # npmInstallHook relies on `npm pack --json | .[0].files` — npm 10 returns
        # an object now, breaking the jq index. Use our own installPhase: move
        # the npm-ci'd package + pruned node_modules into $out.
        dontNpmInstall = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/node_modules/handmux
          cp -r package.json package-lock.json LICENSE README.md bin dist $out/lib/node_modules/handmux/
          npm prune --omit=dev --no-save
          cp -r node_modules $out/lib/node_modules/handmux/
          nodejsInstallExecutables "$out/lib/node_modules/handmux/package.json"
          runHook postInstall
        '';

        meta = {
          description = "A mobile vibe-coding cockpit built on tmux — drive your live session from your phone";
          homepage = "https://handmux.com";
          license = lib.licenses.agpl3Only;
          mainProgram = "handmux";
        };
      };

      cfg = config.programs.handmux;

      # Pi integration wrapper (~/.pi/agent/extensions/handmux/index.ts).
      # Handmux's `agent enable pi` writes exactly this file (piExtension.js):
      # a static wrapper importing the connector from the pinned store path
      # with ?handmux=sha256(connector). We generate it in Nix — deterministic
      # (pinned pkg), bump-proof, no runtime step. The file lands inside
      # extensionsDir (repo symlink) → pi discovers it automatically.
      piConnectorFile = "${cfg.package}/lib/node_modules/handmux/dist/connectors/pi/index.js";
      piFingerprint = builtins.hashFile "sha256" piConnectorFile; # hex, matches handmux's digest('hex')
      piEntryUrl = "file://${piConnectorFile}?handmux=${piFingerprint}";
      piWrapperText = ''
        // handmux-managed-pi-extension:v1
        // handmux-entry:${piEntryUrl}
        // This tiny wrapper is owned by Handmux. Pi loads it from its documented global extension path.
        // Native ESM import preserves the fingerprint that Pi's jiti strips from static re-exports.
        import { importPiConnector } from "data:text/javascript;base64,ZXhwb3J0IGZ1bmN0aW9uIGltcG9ydFBpQ29ubmVjdG9yKHNwZWNpZmllcikgeyByZXR1cm4gaW1wb3J0KHNwZWNpZmllcik7IH0K";
        export default async function handmux(api) {
          const connector = await importPiConnector("${piEntryUrl}");
          return connector.default(api);
        }
      '';

    in
    {
      options.programs.handmux = {
        enable = lib.mkEnableOption "handmux mobile cockpit (tmux phone frontend)";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkg;
          description = "handmux package to use";
        };
        # Autostart the handmux server on login (systemd user service).
        enableServer = lib.mkEnableOption "handmux server autostart (systemd user service)";
        port = lib.mkOption {
          type = lib.types.int;
          default = 19999;
          description = "handmux server listen port";
        };
        # Name shown in browser tab + home-screen icon.
        name = lib.mkOption {
          type = lib.types.str;
          default = "handmux";
          description = "app name shown in the browser tab / home-screen icon";
        };
        # Pi integration: write ~/.pi/agent/extensions/handmux/index.ts wrapper
        # (equivalent of `handmux agent enable pi`).
        enableAgentPi = lib.mkEnableOption "Pi integration wrapper (~/.pi/agent/extensions/handmux/index.ts)";
        # agenix EnvironmentFile (KEY=VALUE lines) holding HANDMUX_TOKEN=<persistent token>.
        # Without a pinned token handmux mints a fresh one every start → phone re-pairs.
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "EnvironmentFile path with HANDMUX_TOKEN=... (e.g. /run/agenix/handmux-token)";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          home.packages = [ cfg.package pkgs.nodejs_22 ];

          # Declarative replacement for `handmux setup`: LAN-only (Tailscale) config.
          # Token NOT in file — comes from tokenFile env (agenix).
          home.file.".handmux/config.json".text = builtins.toJSON {
            tunnel = "none";
            port = cfg.port;
            name = cfg.name;
          };
        })
        (lib.mkIf cfg.enableServer {
          # Handmux needs Node ≥ 22.16 at launch (bin shim checks runtime version);
          # tmux on PATH for its own exec calls.
          systemd.user.services.handmux = {
            Unit = {
              Description = "handmux — drive your tmux from your phone";
              After = [ "network-online.target" ];
            };
            Service = {
              Type = "simple";
              Restart = "always";
              RestartSec = 2;
              Environment = "PATH=${lib.makeBinPath [ pkgs.nodejs_22 pkgs.tmux ]}:/usr/bin:/bin";
              ExecStart = "${lib.getExe cfg.package} start --port ${toString cfg.port}";
            };
            Install.WantedBy = [ "default.target" ];
          };
        })
        (lib.mkIf (cfg.enableAgentPi) {
          # Write the wrapper directly into the repo extensions dir (the
          # ~/.pi/agent/extensions symlink points here) — deterministic, no
          # dependency on symlink-creation order at activation. Lands in repo
          # tree as an untracked file; pi discovers it as a normal loader.
          home.file."${config.home.homeDirectory}/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/handmux/index.ts".text = piWrapperText;
        })
        (lib.mkIf (cfg.enableServer && cfg.tokenFile != null) {
          systemd.user.services.handmux.Service.EnvironmentFile = [ cfg.tokenFile ];
        })
      ];
    };
}