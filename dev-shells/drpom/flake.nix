{
  description = "DrPOM dev shell";
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/master";
    };
    biome-pin = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    { nixpkgs, biome-pin, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor =
        system: pkgs:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system nixpkgs;
          biome-pin-pkgs = pkgsFor system biome-pin;
          androidComp = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [
              "36"
              "latest"
            ];
            systemImageTypes = [ "google_apis_playstore" ];
            abiVersions = [
              "armeabi-v7a"
              "arm64-v8a"
            ];
            includeNDK = true;
            ndkVersions = [
              "27.0.12077973"
              "27.1.12297006"
            ];
            includeEmulator = true;
            includeSystemImages = true;
            includeExtras = [ "extras;google;auto" ];
          };
          androidStudio = pkgs.android-studio.withSdk androidComp.androidsdk;
          ANDROID_HOME = "${androidComp.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";

          # Argent: upstream git omits Simulator binaries (npm-only); the workspace lockfile is
          # missing resolved URLs (~npm/cli#6301), so fetchNpmDeps cannot satisfy npm ci reliably.
          # Package the registry release (matches https://github.com/software-mansion/argent releases).
          argentVersion = "0.6.0";
          argentNpmRelease = pkgs.fetchurl {
            url = "https://registry.npmjs.org/@swmansion/argent/-/argent-${argentVersion}.tgz";
            hash = "sha256-2bUPzWbTJyxZrf91WV1f8bAVzt/IfGherSOHRv3ySWA=";
          };
          argent = pkgs.stdenvNoCC.mkDerivation {
            pname = "argent";
            version = argentVersion;
            src = argentNpmRelease;
            nativeBuildInputs = [
              pkgs.nodejs_22
              pkgs.makeWrapper
            ];
            unpackPhase = ''
              tar -xzf "$src"
            '';
            sourceRoot = "package";
            installPhase = ''
              mkdir -p "$out/libexec/argent"
              cp -r . "$out/libexec/argent/"
              chmod +x "$out/libexec/argent/bin"/* 2>/dev/null || true

              mkdir -p "$out/bin"
              makeWrapper "${pkgs.nodejs_22}/bin/node" "$out/bin/argent" \
                --add-flags "$out/libexec/argent/dist/cli.js"

              ln -sf "$out/libexec/argent/bin/simulator-server" "$out/bin/argent-simulator-server"
              ln -sf "$out/libexec/argent/bin/ax-service" "$out/bin/ax-service"
            '';
            meta = {
              description = "Agentic toolkit for iOS Simulator (MCP)";
              homepage = "https://github.com/software-mansion/argent";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "argent";
              platforms = pkgs.lib.platforms.darwin;
            };
          };

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

          # Use the same buildToolsVersion here
          # GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";
        in
        {
          default =
            pkgs.mkShell {
              packages =
                with pkgs;
                [
                  nodejs_22
                  deno
                  pnpm
                  jdk17
                  kotlin
                  kotlin-language-server
                  biome-pin-pkgs.biome
                  jq
                  rclone
                  postgresql
                  tailwindcss-language-server
                  easCli
                  yaml-language-server
                ]
                ++ (if pkgs.stdenv.isDarwin then [ argent ] else [ ])
                ++ (
                  if pkgs.stdenv.isLinux then
                    [
                      android-studio
                      androidenv.androidPkgs.platform-tools
                      androidStudio
                      androidComp.androidsdk
                      chromium
                    ]
                  else
                    [ ]
                );
              NODE_OPTIONS = "--experimental-vm-modules";
              BIOME_BINARY = "${biome-pin-pkgs.biome}/bin/biome";
              shellHook = ''
                export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
                ${
                  if pkgs.stdenv.isDarwin then
                    ''
                      export ANDROID_HOME=/Volumes/Kingston480GB/Android/sdk
                      export BUN_INSTALL="$HOME/.bun"
                      export PATH="$BUN_INSTALL/bin:$PATH"
                      unset CC CXX
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
                    ''
                }
              '';
            }
            // pkgs.lib.mkIf pkgs.stdenv.isDarwin {
              DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
            };
        }
      );
    };
}
