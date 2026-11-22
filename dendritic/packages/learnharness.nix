{
  perSystem =
    { pkgs, ... }:
    let
      src = pkgs.fetchurl {
        url = "https://github.com/amosblomqvist/learnharness/releases/download/v0.7.0/LearnHarness-0.7.0-x86_64.AppImage";
        hash = "sha256-dyteBNOAy+inKnXb/yaa62pH9NRFJxGx2oBZqHIGdhM=";
      };
      appimage = pkgs.appimageTools.wrapType2 {
        pname = "learnharness";
        version = "0.7.0";
        inherit src;
      };
      # Electron userData pinned to ~/LearnHarness so syncthing mirrors it between hosts.
      wrapper = pkgs.writeShellScriptBin "learnharness" ''
        [ -f "$HOME/.config/learnharness/env" ] && . "$HOME/.config/learnharness/env"
        exec ${appimage}/bin/learnharness --user-data-dir="$HOME/LearnHarness" "$@"
      '';
      extracted = pkgs.appimageTools.extractType2 {
        pname = "learnharness";
        version = "0.7.0";
        inherit src;
      };
      icons = pkgs.runCommand "learnharness-icons" { } ''
        mkdir -p $out/share/icons
        cp -r ${extracted}/usr/share/icons/* $out/share/icons/
      '';
      desktopItem = pkgs.makeDesktopItem {
        name = "learnharness";
        desktopName = "LearnHarness";
        comment = "An agent harness for learning.";
        exec = "learnharness %U";
        icon = "learnharness";
        type = "Application";
        categories = [ "Education" ];
        startupWMClass = "learnharness";
        terminal = false;
      };
    in
    {
      packages.learnharness = pkgs.symlinkJoin {
        name = "learnharness";
        paths = [
          wrapper
          desktopItem
          icons
        ];
      };
    };
}
