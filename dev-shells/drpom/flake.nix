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
            # (androidenv.emulateApp {
            #   name = "drpom";
            #   platformVersion = "35";
            #   abiVersion = "x86_64";
            #   systemImageType = "google_apis_playstore";
            # })
          ] ++ (with pkgs.nodePackages; [ firebase-tools ]);
        shellHook = ''
          export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
        '';
      };
    };
}
