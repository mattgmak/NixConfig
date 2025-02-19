{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-glow";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "Reledia";
    repo = "glow.yazi";
    rev = "5ce76dc92ddd0dcef36e76c0986919fda3db3cf5";
    hash = "sha256-UljcrXXO5DZbufRfavBkiNV3IGUNct31RxCujRzC9D4=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/glow
    cp -r $src/* $out/share/yazi/plugins/glow/
  '';

  meta = with lib; {
    description = "Plugin for Yazi to preview markdown files with glow";
    homepage = "https://github.com/Reledia/glow.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
