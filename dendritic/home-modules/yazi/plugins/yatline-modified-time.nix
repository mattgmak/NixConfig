{
  flake.yaziPluginYatlineModifiedTime =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-modified-time";
      version = "unstable-2025-09-04";

      src = fetchFromGitHub {
        owner = "wekauwau";
        repo = "yatline-modified-time.yazi";
        rev = "2d334719fc24ca034e46affb05187bcb2ee55225";
        hash = "sha256-sus3GNM6CEfL5AmhJfRLT56MH3+xU20vcIfW9+C1RLg=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Yatline addon for the modification time of the hovered file";
        homepage = "https://github.com/wekauwau/yatline-modified-time.yazi";
        license = licenses.mit;
        maintainers = [ "wekauwau" ];
        platforms = platforms.all;
      };
    };
}
