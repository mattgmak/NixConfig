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
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          home.packages = [ cfg.package pkgs.nodejs_22 ];
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
      ];
    };
}