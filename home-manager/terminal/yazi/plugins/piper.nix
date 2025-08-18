{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "yaziPlugins-piper";
  version = "unstable-2025-08-18";

  src = ./piper;

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/piper
    cp -r $src/* $out/share/yazi/plugins/piper/
  '';

  meta = with lib; {
    description = "Pipe any shell command as a previewer";
    homepage = "https://github.com/yazi-rs/plugins/tree/main/piper.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
