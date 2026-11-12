{
  flake.yaziPluginYatlineSelectedSize =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-selected-size";
      version = "unstable-2026-08-25";

      src = fetchFromGitHub {
        owner = "pakhromov";
        repo = "yatline-selected-size.yazi";
        rev = "d15f43104d925dea9aa67e74d739e21b3f7fb71e";
        hash = "sha256-+KUXxnsrHNKVthmSvY3YdSPcX8gdAOmc0e84uYJc+1U=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Yatline addon for the total size of the selected files";
        homepage = "https://github.com/pakhromov/yatline-selected-size.yazi";
        license = licenses.mit;
        maintainers = [ "pakhromov" ];
        platforms = platforms.all;
      };
    };
}
