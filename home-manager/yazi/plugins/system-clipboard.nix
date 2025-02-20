{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "yaziPlugins-system-clipboard";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "orhnk";
    repo = "system-clipboard.yazi";
    rev = "7775a80e8d3391e0b3da19ba143196960a4efc48";
    hash = "sha256-tfR9XHvRqm7yPbTu/joBDpu908oceaUoBiIImehMobk=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/system-clipboard
    cp -r $src/* $out/share/yazi/plugins/system-clipboard/
    chmod -R +x $out/share/yazi/plugins/system-clipboard/
  '';

  meta = with lib; {
    description = "System clipboard integration for Yazi";
    homepage = "https://github.com/orhnk/system-clipboard.yazi";
    license = licenses.mit;
    maintainers = [ "orhnk" ];
    platforms = platforms.all;
  };
}