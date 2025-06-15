{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-glow";
  version = "unstable-2025-06-15";

  src = fetchFromGitHub {
    owner = "Reledia";
    repo = "glow.yazi";
    rev = "bd3eaa58c065eaf216a8d22d64c62d8e0e9277e9";
    hash = "sha256-mzW/ut/LTEriZiWF8YMRXG9hZ70OOC0irl5xObTNO40=";
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
