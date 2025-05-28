{
  description = "DrPOM dev shell";
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; }; };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.android_sdk.accept_license = true;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs;
          [
            nodejs_20
            androidenv.androidPkgs.platform-tools
            chromium
            deno
            android-studio
            pnpm
          ] ++ (with pkgs.nodePackages; [ firebase-tools eas-cli ]);
        shellHook = ''
          export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
          export ANDROID_HOME=~/Android/Sdk
        '';
      };
    };
}
