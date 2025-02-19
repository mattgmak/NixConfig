{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-glow";
  version = "unstable-2024-11-21";

  src = fetchFromGitHub {
    owner = "Reledia";
    repo = "glow.yazi";
    rev = "388e847dca6497cf5903f26ca3b87485b2de4680";
    hash = "sha256-fKJ5ld5xc6HsM/h5j73GABB5i3nmcwWCs+QSdDPA9cU=";
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
