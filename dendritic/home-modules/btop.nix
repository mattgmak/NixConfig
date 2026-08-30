{
  flake.homeModules.btop =
    { pkgs, ... }:
    let
      btopWithNvml = pkgs.runCommand "btop-nvidia"
        {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        }
        ''
          makeWrapper ${pkgs.btop}/bin/btop $out/bin/btop \
            --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
        '';
    in
    {
      programs.btop = {
        enable = true;
        package = btopWithNvml;
        settings = {
          update_ms = 1000;
        };
      };
    };
}
