# Halogen Dashboard — https://github.com/Quat3rnion/halogen-dashboard
# The Collector embeds web/dist at compile time (rust-embed debug-embed), so the
# pnpm build is linked into the Rust source tree before cargo runs.
{ self, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      repoRoot =
        /. + builtins.unsafeDiscardStringContext "${self}/vendor/Quat3rnion/halogen-dashboard";
      skipGenerated = p: _: !builtins.elem (baseNameOf p) [ ".git" "node_modules" "dist" ];

      webSrc = builtins.path {
        name = "halogen-dashboard-web-src";
        path = repoRoot + "/web";
        filter = skipGenerated;
      };

      # nodejs_22 and pnpm_11 match the upstream Dockerfile (node:22, corepack
      # pnpm@11.5.1) and the lockfile format (lockfileVersion 9.0).
      web = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "halogen-dashboard-web";
        version = "0.1.0";
        src = webSrc;

        __structuredAttrs = true;
        strictDeps = true;
        dontStrip = true;

        nativeBuildInputs = [
          pkgs.nodejs_22
          pkgs.pnpm_11
          pkgs.pnpmConfigHook
          pkgs.writableTmpDirAsHomeHook
        ];

        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (finalAttrs) pname version src;
          pnpm = pkgs.pnpm_11;
          fetcherVersion = 4;
          hash = "sha256-xGuWDkkG+mRc+cs7oDHOqsCcGZmaU0Gn9cJOsR0GYn0=";
        };

        buildPhase = ''
          runHook preBuild
          pnpm build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r dist $out/dist
          runHook postInstall
        '';

        meta = {
          description = "Halogen dashboard web page (Svelte 5 + uPlot)";
          homepage = "https://github.com/Quat3rnion/halogen-dashboard";
          license = with lib.licenses; [
            asl20
            mit
          ];
        };
      });
    in
    {
      packages.halogen-dashboard-web = web;

      packages.halogen-dashboard = pkgs.rustPlatform.buildRustPackage {
        pname = "halogen-dashboard";
        version = "0.1.0";

        src = builtins.path {
          name = "halogen-dashboard-src";
          path = repoRoot;
          filter = skipGenerated;
        };

        cargoHash = "sha256-TkTW//u/PFxl+vDA4LkPUEYpdx6MSq2677EFRW20C3c=";

        # Upstream ships a release-only image (Cargo.toml sets lto = "thin").
        buildType = "release";

        # rust-embed reads ../../web/dist from crates/collector at compile time.
        postPatch = ''
          ln -s ${web}/dist web/dist
        '';

        meta = {
          description = "Collector and dashboard for the Halogen LLM inference server";
          homepage = "https://github.com/Quat3rnion/halogen-dashboard";
          license = with lib.licenses; [
            asl20
            mit
          ];
          mainProgram = "halogen-dashboard";
        };

        # live.rs writes to a hardcoded /arboretum/tmp path from the author's host.
        doCheck = false;
      };
    };
}
