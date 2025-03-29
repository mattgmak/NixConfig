{ lib, stdenv, fetchgit, fzf, ripgrep, bat }:

stdenv.mkDerivation {
  pname = "yaziPlugins-fg";
  version = "unstable-2025-02-20";

  src = fetchgit {
    url = "https://gitee.com/DreamMaoMao/fg.yazi.git";
    rev = "daf696065d65e61a1b3026ab8190351203513d51";
    hash = "sha256-dcidPBhc0+NvPb80hK+kUoq+PxspceFCliyEc7K3OTk=";
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
