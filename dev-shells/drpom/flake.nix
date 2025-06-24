{
  description = "DrPOM dev shell";
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; }; };

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
    in {
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          # Platform-specific browser selection
          browser =
            if pkgs.stdenv.isDarwin then pkgs.google-chrome else pkgs.chromium;
        in {
          default = pkgs.mkShell {
            packages = with pkgs;
              [ nodejs_20 browser deno pnpm ]
              ++ (with pkgs.nodePackages; [ firebase-tools eas-cli ])
              ++ (if pkgs.stdenv.isLinux then [
                android-studio
                androidenv.androidPkgs.platform-tools
              ] else
                [ ]);
            shellHook = ''
              export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
              ${if pkgs.stdenv.isDarwin then ''
                export ANDROID_HOME=~/Library/Android/sdk
                export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
              '' else
                "export ANDROID_HOME=~/Android/Sdk"}
            '';
          };
        });
    };
}
