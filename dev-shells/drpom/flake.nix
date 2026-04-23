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
                  eas-cli
                ]
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
                      export ANDROID_HOME=~/Library/Android/sdk
                      export BUN_INSTALL="$HOME/.bun"
                      export PATH="$BUN_INSTALL/bin:$PATH"
                      unset CC CXX
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
