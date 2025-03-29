{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-searchjump";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "DreamMaoMao";
    repo = "searchjump.yazi";
    rev = "df6ee75772d4095c740572fa4adb06a27857c721";
    hash = "sha256-JgHxItaE/C7xdc7fe35KfLZGJKiIvurKizPH9cOb3Z0=";
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