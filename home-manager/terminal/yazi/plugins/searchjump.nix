{ lib, stdenv, fetchgit }:

stdenv.mkDerivation {
  pname = "yaziPlugins-searchjump";
  version = "unstable-2025-06-15";

  src = fetchgit {
    url = "https://gitee.com/DreamMaoMao/searchjump.yazi.git";
    rev = "cab627c1ab0a";
    hash = "sha256-l0mNqZIS3IAPpcIxN17JOuc09UHYmzRtRR8/fGu3oe8=";
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
