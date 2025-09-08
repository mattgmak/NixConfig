{
  description = "DrPOM dev shell";
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    biome-pin = { url = "github:nixos/nixpkgs/nixos-unstable"; };
  };

  outputs = { nixpkgs, biome-pin, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: pkgs:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
    in {
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system nixpkgs;
          biome-pin-pkgs = pkgsFor system biome-pin;
          # Platform-specific browser selection
          browser =
            if pkgs.stdenv.isDarwin then pkgs.google-chrome else pkgs.chromium;
        in {
          default = pkgs.mkShell {
            packages = with pkgs;
              [
                nodejs_20
                browser
                deno
                pnpm
                jdk17
                kotlin
                kotlin-language-server
                biome-pin-pkgs.biome
              ] ++ (with pkgs.nodePackages; [ firebase-tools eas-cli vercel ])
              ++ (if pkgs.stdenv.isLinux then [
                android-studio
                androidenv.androidPkgs.platform-tools
              ] else
                [ ]);
            NODE_OPTIONS = "--experimental-vm-modules";
            BIOME_BINARY = "${biome-pin-pkgs.biome}/bin/biome";
            shellHook = ''
              export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
              ${if pkgs.stdenv.isDarwin then ''
                export ANDROID_HOME=~/Library/Android/sdk
              '' else ''
                export ANDROID_HOME=~/Android/Sdk
              ''}
            '';
          } // pkgs.lib.mkIf pkgs.stdenv.isDarwin {
            DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
          };
        });
    };
}
