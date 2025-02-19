{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-yaziline";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "llanosrocas";
    repo = "yaziline";
    rev = "main"; # Will be updated by the script
    hash =
      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be updated by the script
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/yaziline
    cp -r $src/* $out/share/yazi/plugins/yaziline/
  '';

  meta = with lib; {
    description = "Yaziline plugin for Yazi file manager";
    homepage = "https://github.com/llanosrocas/yaziline";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
