{
  perSystem =
    { pkgs, ... }:
    {
      # Electron userData pinned to ~/LearnHarness so syncthing mirrors it between hosts.
      packages.learnharness = pkgs.writeShellScriptBin "learnharness" ''
        exec ${pkgs.appimageTools.wrapType2 {
          pname = "learnharness";
          version = "0.7.0";
          src = pkgs.fetchurl {
            url = "https://github.com/amosblomqvist/learnharness/releases/download/v0.7.0/LearnHarness-0.7.0-x86_64.AppImage";
            hash = "sha256-dyteBNOAy+inKnXb/yaa62pH9NRFJxGx2oBZqHIGdhM=";
          };
        }}/bin/learnharness --user-data-dir="$HOME/LearnHarness" "$@"
      '';
    };
}
