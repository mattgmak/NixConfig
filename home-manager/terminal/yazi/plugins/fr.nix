{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-fr";
  version = "unstable-2025-07-28";

  src = fetchFromGitHub {
    owner = "lpnh";
    repo = "fr.yazi";
    rev = "3d32e55b7367334abaa91f36798ef723098d0a6b";
    hash = "sha256-CrKwFMaiEK+TNW6GRZzyt9MfOmjIb3vw0hBpBXyn16k=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/fr
    cp -r $src/* $out/share/yazi/plugins/fr/
  '';

  meta = with lib; {
    description = "Fuzzy finder plugin for Yazi file manager";
    homepage = "https://github.com/lpnh/fr.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
