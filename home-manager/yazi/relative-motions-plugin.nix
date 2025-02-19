{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-relative-motions";
  version = "unstable-2024-12-14";

  src = fetchFromGitHub {
    owner = "dedukun";
    repo = "relative-motions.yazi";
    rev = "df97039a04595a40a11024f321a865b3e9af5092";
    hash = "sha256-csX8T2a5f7k6g2mlR+08rm0qBeWdI4ABuja+klIvwqw=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/relative-motions
    cp -r $src/* $out/share/yazi/plugins/relative-motions/
  '';

  meta = with lib; {
    description =
      "This plugin adds the some basic vim motions like 3k, 12j, 10gg, etc.";
    homepage = "https://github.com/dedukun/relative-motions.yazi.git";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
