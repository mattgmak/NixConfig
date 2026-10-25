{
  perSystem =
    { pkgs, ... }:
    let
      base = pkgs.stdenvNoCC.mkDerivation {
        pname = "tmax";
        version = "4541261";

        src = ../../vendor/theo-kirby/tmax;

        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share
          # cp -R keeps the upstream modes, so tmax.tmux stays executable.
          cp -R . $out/share/tmax

          runHook postInstall
        '';
      };
    in
    {
      # meta is attached after the derivation: perSystem pkgs has allowUnfree = false
      # and rejects an unfree `meta` argument, while hosts set allowUnfree = true.
      packages.tmax = base // {
        meta = with pkgs.lib; {
          description = "Small additions on top of tmux: remote hosts, session switcher, agent status";
          homepage = "https://github.com/theo-kirby/tmax";
          # The repo carries no LICENSE file, so it stays all rights reserved.
          license = licenses.unfree;
          platforms = platforms.unix;
        };
      };
    };
}
