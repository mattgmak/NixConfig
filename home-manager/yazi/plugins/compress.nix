{ lib, stdenv, fetchFromGitHub, p7zip, gzip, xz, bzip2, zstd }:

stdenv.mkDerivation {
  pname = "yaziPlugins-compress";
  version = "unstable-2025-02-20";

  src = fetchFromGitHub {
    owner = "KKV9";
    repo = "compress.yazi";
    rev = "60b24af23d1050f1700953a367dd4a2990ee51aa";
    hash = "sha256-Yf5R3H8t6cJBMan8FSpK3BDSG5UnGlypKSMOi0ZFqzE=";
  };

  buildInputs = [
    p7zip # For .7z and .zip
    gzip # For .tar.gz
    xz # For .tar.xz
    bzip2 # For .tar.bz2
    zstd # For .tar.zst
  ];

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/compress
    cp -r $src/* $out/share/yazi/plugins/compress/
  '';

  meta = with lib; {
    description = "A Yazi plugin that compresses selected files to an archive";
    homepage = "https://github.com/KKV9/compress.yazi";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
