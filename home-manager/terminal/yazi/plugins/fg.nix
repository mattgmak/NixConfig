{ lib, stdenv, fetchgit, fzf, ripgrep, bat }:

stdenv.mkDerivation {
  pname = "yaziPlugins-fg";
  version = "unstable-2025-06-15";

  src = fetchgit {
    url = "https://gitee.com/DreamMaoMao/fg.yazi.git";
    rev = "46a5c16f62f415f691319f984b9548249b0edc96";
    hash = "sha256-B6Feg8icshHQYv04Ee/Bo9PPaiDPRyt1HwpirI/yXj8=";
  };

  buildInputs = [
    fzf # Required dependency
    ripgrep # Required dependency
    bat # Required dependency
  ];

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/fg
    cp -r $src/* $out/share/yazi/plugins/fg/
  '';

  meta = with lib; {
    description = "Fuzzy finder plugin for Yazi file manager";
    homepage = "https://gitee.com/DreamMaoMao/fg.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
