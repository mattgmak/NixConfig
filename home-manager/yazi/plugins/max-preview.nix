{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-max-preview";
  version = "unstable-2025-02-20";

  src = ./max-preview/src;

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/max-preview
    cp -r $src/* $out/share/yazi/plugins/max-preview/
    chmod -R +x $out/share/yazi/plugins/max-preview/
  '';

  meta = with lib; {
    description = "Maximize or restore the preview pane";
    homepage = "https://github.com/SUSTech-data/max-preview.yazi";
    license = licenses.mit;
    maintainers = [ "SUSTech-data" ];
    platforms = platforms.all;
  };
}
