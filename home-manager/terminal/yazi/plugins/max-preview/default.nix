{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-max-preview";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "SUSTech-data";
    repo = "max-preview.yazi";
    rev = "b65aafa4045adb7b1257aceee2e37db1456ae3d3";
    hash = "sha256-7Lg3LVOMUC/0NNh9dU3ttiKZ3kz6zm86IqSd5/2tc0c=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/max-preview
    cp -r $src/* $out/share/yazi/plugins/max-preview/
  '';

  meta = with lib; {
    description = "Maximize or restore the preview pane";
    homepage = "https://github.com/SUSTech-data/max-preview.yazi";
    license = licenses.mit;
    maintainers = [ "SUSTech-data" ];
    platforms = platforms.all;
  };
}