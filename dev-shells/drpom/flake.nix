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
              "x86_64"
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
          androidStudio =
            (pkgs.android-studio.override {
              tiling_wm = true;
              forceWayland = true;
            }).withSdk
              androidComp.androidsdk;
          ANDROID_HOME = "${androidComp.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";

          # Argent: upstream git omits Simulator binaries (npm-only); the workspace lockfile is
          # missing resolved URLs (~npm/cli#6301), so fetchNpmDeps cannot satisfy npm ci reliably.
          # Package the registry release (matches https://github.com/software-mansion/argent releases).
          #
          # The registry tarball ships prebuilt hosts under bin/<platformKey>/: darwin (Mach-O
          # universal, x86_64 + arm64), linux + linux-arm64 (ELF), win32. Argent gates its iOS-only
          # tools behind requireDarwin()/process.platform, so a Linux install is Android-emulator
          # only — which is all this devshell can host anyway (iOS Simulator needs macOS).
          argentVersion = "0.25.2";
          argentNpmRelease = pkgs.fetchurl {
            url = "https://registry.npmjs.org/@swmansion/argent/-/argent-${argentVersion}.tgz";
            hash = "sha256-V0d9DBz5qI7d69SueP55bxL2SutOcFoUd0VrZUkyvt4=";
          };
          # hostPlatformKey() from the bundled tool-server / bin/argent-simulator-server.cjs.
          argentPlatformKey =
            if pkgs.stdenv.isLinux then "linux" else "darwin";
          # The tool-server spawns bin/<platformKey>/simulator-server itself (execFileSync, no
          # wrapper in between), so the Linux ELF has to be self-contained: /lib64/ld-linux does
          # not exist on NixOS, libgcc_s.so.1 lives in the gcc lib dir, and the Rust binary lists
          # ld-linux-x86-64.so.2 as a DT_NEEDED so glibc's lib dir must be on RUNPATH too
          # (runpath, not --force-rpath, so it does not leak into simulator-server's children).
          argentSimulatorServerPatch = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            patchelf \
              --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
              --set-rpath ${pkgs.lib.makeLibraryPath [pkgs.glibc pkgs.gcc.cc.lib]} \
              "$out/libexec/argent/bin/linux/simulator-server"
          '';
          # ax-service is a Mach-O slice in every variant, including the "platform-neutral"
          # bin/tcp one, so it stays darwin-only.
          argentAxServiceLink = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
            ln -s "$out/libexec/argent/bin/darwin/ax-service" "$out/bin/ax-service"
          '';
          argent = pkgs.stdenvNoCC.mkDerivation {
            pname = "argent";
            version = argentVersion;
            src = argentNpmRelease;
            nativeBuildInputs =
              [
                pkgs.nodejs_22
                pkgs.makeWrapper
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.patchelf ];
            dontConfigure = true;
            dontBuild = true;
            # Prebuilt Mach-O/ELF blobs, not build output: leave the binaries alone.
            dontPatchELF = true;
            unpackPhase = ''
              tar -xzf "$src"
            '';
            sourceRoot = "package";
            installPhase = ''
              runHook preInstall

              mkdir -p "$out/libexec/argent"
              cp -r . "$out/libexec/argent/"
              chmod +x "$out/libexec/argent/bin"/* "$out/libexec/argent/bin"/*/* 2>/dev/null || true

              mkdir -p "$out/bin"
              # dist/ ships esbuild bundles, so no node_modules install is needed.
              makeWrapper ${pkgs.nodejs_22}/bin/node "$out/bin/argent" \
                --add-flags "$out/libexec/argent/dist/cli.js"

              # The tool-server spawns bin/<platformKey>/simulator-server itself (execFileSync,
              # no wrapper in between), so the Linux ELF has to be self-contained: /lib64/ld-linux
              # does not exist on NixOS and libgcc_s.so.1 lives in the gcc lib dir.
              ${argentSimulatorServerPatch}

              ln -s "$out/libexec/argent/bin/${argentPlatformKey}/simulator-server" \
                "$out/bin/argent-simulator-server"

              ${argentAxServiceLink}

              runHook postInstall
            '';
            meta = {
              description = "Agentic toolkit for iOS Simulator and Android Emulator (MCP)";
              homepage = "https://github.com/software-mansion/argent";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "argent";
              platforms = pkgs.lib.platforms.unix;
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
                  droast
                  yaml-language-server
                  act
                  railway
                  argent
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
              # BIOME_BINARY = "${biome-pin-pkgs.biome}/bin/biome";
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
            }
            // pkgs.lib.mkIf pkgs.stdenv.isDarwin {
              DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
            };
        }
      );
    };
}
