{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-searchjump";
  version = "unstable-2025-06-15";

  src = fetchFromGitHub {
    owner = "DreamMaoMao";
    repo = "searchjump.yazi";
    rev = "fe884f42fbb642b0e3a9f43487f9c6561b9d4fc6";
    hash = "sha256-Vss5CLoFmy5r5hX69CFLF2u2Mz0P8hDgFy8riLftRFk=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/searchjump
    cp -r $src/* $out/share/yazi/plugins/searchjump/
    chmod -R +x $out/share/yazi/plugins/searchjump/
  '';

  meta = with lib; {
    description = "Search and jump to files in Yazi";
    homepage = "https://github.com/DreamMaoMao/searchjump.yazi";
    license = licenses.mit;
    maintainers = [ "DreamMaoMao" ];
    platforms = platforms.all;
  };
}