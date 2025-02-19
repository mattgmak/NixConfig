{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-max-preview";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "beb586aed0d41e6fdec5bba7816337fdad905a33";
    hash = "sha256-enIt79UvQnKJalBtzSEdUkjNHjNJuKUWC4L6QFb3Ou4=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/max-preview
    cp -r $src/max-preview.yazi/* $out/share/yazi/plugins/max-preview/
  '';

  meta = with lib; {
    description = "Maximize or restore the preview pane";
    homepage = "https://github.com/yazi-rs/plugins/tree/main/max-preview.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
