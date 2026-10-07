# DrPOM dev shell: `nix develop ~/NixConfig#drpom` (or `use flake ~/NixConfig#drpom`).
# Folded in from the former standalone dev-shells/drpom flake.
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    # Plain Nix `if`, not lib.mkIf: flake-parts does not unwrap mkIf, and a bare
    # mkIf at the perSystem root would register `_type`/`_then` as option names.
    if !(builtins.elem system [ "x86_64-linux" "aarch64-darwin" ]) then
      { }
    else
      let
        # perSystem's `pkgs` is plain nixpkgs.legacyPackages; it carries none of this
        # config. Import nixpkgs directly so unfree packages resolve and the Android
        # SDK licence is pre-accepted (androidenv refuses to compose otherwise).
        pkgsFor = pkgs:
          import pkgs {
            inherit system;
            config.allowUnfree = true;
            config.android_sdk.accept_license = true;
          };
        pkgs = pkgsFor inputs.nixpkgs;

        androidComp = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [
            "36"
            "latest"
          ];
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [
            "x86_64"
            "arm64-v8a"
          ];
          buildToolsVersions = [ "36.0.0" ];
          includeNDK = true;
          ndkVersions = [
            "27.0.12077973"
            "27.1.12297006"
          ];
          includeEmulator = true;
          includeSystemImages = true;
          includeExtras = [ "extras;google;auto" ];
        };
        androidStudio =
          (pkgs.android-studio.override {
            tiling_wm = true;
            forceWayland = true;
          }).withSdk
            androidComp.androidsdk;
        ANDROID_HOME = "${androidComp.androidsdk}/libexec/android-sdk";
        ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";

        # Registry release from https://www.npmjs.com/package/eas-cli (npm tarball has no lockfile).
        easCliVersion = "19.1.0";
        easCli = pkgs.buildNpmPackage {
          pname = "eas-cli";
          version = easCliVersion;
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/eas-cli/-/eas-cli-${easCliVersion}.tgz";
            hash = "sha256-Wh2gE/Ey0uJkHS4iug6rK0HhVSwuFyTO9jwOJYWAZnc=";
          };
          sourceRoot = "package";

          postPatch = ''
            cp ${./eas-cli-package-lock.json} package-lock.json
          '';

          npmDepsHash = "sha256-sbgt2quVZrYOrpHmZheJZYmp3iwQw+iSUgWo3NQb4/Q=";

          nodejs = pkgs.nodejs_22;

          npmFlags = [
            "--legacy-peer-deps"
            "--omit=dev"
            "--ignore-scripts"
          ];
          npmInstallFlags = [
            "--legacy-peer-deps"
            "--omit=dev"
            "--ignore-scripts"
          ];
          npmPackFlags = [ "--ignore-scripts" ];

          dontNpmBuild = true;

          meta = {
            description = "EAS command line tool";
            homepage = "https://github.com/expo/eas-cli";
            license = pkgs.lib.licenses.mit;
            mainProgram = "eas";
          };
        };

        # pnpm 10.34.6 is the registry latest-10 but never landed in nixpkgs: nixpkgs goes
        # 10.33.4 -> 11.1.1, so neither pkgs.pnpm nor multiverse's mv.version can reach it
        # (multiverse only indexes versions nixpkgs actually shipped). Build the registry
        # tarball instead, same shape as nixpkgs' pkgs/development/tools/pnpm/generic.nix:
        # the tarball ships prebuilt bundles (dist/pnpm.cjs, bundled node_modules), so
        # there is nothing to build and no lockfile to resolve.
        pnpmVersion = "10.34.6";
        pnpmPinned = pkgs.stdenvNoCC.mkDerivation {
          pname = "pnpm";
          version = pnpmVersion;
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/pnpm/-/pnpm-${pnpmVersion}.tgz";
            hash = "sha256-RNfbkPy7IxW1gfhZiakTRmdlQh/GVsKOgPrBt6tb5FY=";
          };
          strictDeps = true;
          dontConfigure = true;
          dontBuild = true;

          nativeBuildInputs = [
            pkgs.bashNonInteractive
            pkgs.makeWrapper
            pkgs.nodejs_22
          ];

          # Prebuilt .node blobs that only enable the reflink fast path; dropping them
          # keeps the closure binaryNativeCode-free, as nixpkgs does.
          postUnpack = ''
            rm -r package/dist/reflink.*node
          '';

          installPhase = ''
            runHook preInstall

            install -d $out/{bin,libexec}
            cp -R . $out/libexec/pnpm
            makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/pnpm \
              --add-flags "$out/libexec/pnpm/bin/pnpm.cjs"
            makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/pnpx \
              --add-flags "$out/libexec/pnpm/bin/pnpx.cjs"

            runHook postInstall
          '';

          passthru = {
            inherit (pkgs.nodejs_22) nodejs;
          };

          meta = {
            description = "Fast, disk space efficient package manager for JavaScript";
            homepage = "https://pnpm.io/";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.unix;
            mainProgram = "pnpm";
          };
        };

        droastVersion = "1.4.11";
        droast = pkgs.rustPlatform.buildRustPackage {
          pname = "dockerfile-roast";
          version = droastVersion;
          src = pkgs.fetchFromGitHub {
            owner = "immanuwell";
            repo = "dockerfile-roast";
            rev = droastVersion;
            hash = "sha256-PcrCsunROEsihepKUX15mLLxXdkawECXQXOM5kDLvY0=";
          };
          cargoHash = "sha256-Uz0FIxSO7nx/JSKIt3OXg9UHmGXY4mXjVOSB9fgi9aU=";
          doCheck = false;
          meta = {
            description = "Dockerfile linter with personality";
            homepage = "https://github.com/immanuwell/dockerfile-roast";
            license = pkgs.lib.licenses.mit;
            mainProgram = "droast";
          };
        };

        # Use the same buildToolsVersion here
        # GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";
      in
      {
        devShells.drpom =
          pkgs.mkShell {
            packages =
              with pkgs;
              [
                nodejs_22
                deno
                pnpmPinned
                jdk17
                kotlin
                kotlin-language-server
                # Formerly a separate `biome-pin` input; the pin was just an older
                # nixos-unstable, so track the flake's own nixpkgs instead.
                biome
                jq
                rclone
                postgresql
                tailwindcss-language-server
                easCli
                droast
                yaml-language-server
                act
                railway
              ]
              ++ (if pkgs.stdenv.isDarwin then [ ] else [ ])
              ++ (
                if pkgs.stdenv.isLinux then
                  [
                    androidenv.androidPkgs.platform-tools
                    androidStudio
                    androidComp.androidsdk
                    chromium
                    glib
                    libsecret
                  ]
                else
                  [ ]
              );
            NODE_OPTIONS = "--experimental-vm-modules";
            shellHook = ''
              export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
              ${
                if pkgs.stdenv.isDarwin then
                  ''
                    export ANDROID_HOME=/Volumes/Kingston480GB/Android/sdk
                    export BUN_INSTALL="$HOME/.bun"
                    export PATH="$BUN_INSTALL/bin:$PATH"
                    unset CC CXX LD
                    # stdenv-darwin overrides DEVELOPER_DIR/SDKROOT with the Nix apple-sdk;
                    # EAS local iOS builds need the real Xcode.app toolchain (xcodebuild).
                    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
                    unset SDKROOT
                    export PATH="/usr/bin:/bin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
                  ''
                else
                  # ''
                  #   export ANDROID_HOME=~/Android
                  # ''
                  ''
                    export ANDROID_HOME=${ANDROID_HOME}
                    export ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}
                    export LD_LIBRARY_PATH="${
                      pkgs.lib.makeLibraryPath [
                        pkgs.libsecret
                        pkgs.glib
                      ]
                    }:$LD_LIBRARY_PATH"
                  ''
              }
            '';
          };
      };
}
