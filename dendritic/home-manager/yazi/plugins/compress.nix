{
  flake.yaziPluginCompress =
    {
      lib,
      stdenv,
      fetchFromGitHub,
      p7zip,
      gzip,
      xz,
      bzip2,
      zstd,
    }:
    stdenv.mkDerivation {
      pname = "yaziPlugins-compress";
      version = "unstable-2025-06-15";

      src = fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "9fc8fe0bd82e564f50eb98b95941118e7f681dc8";
        hash = "sha256-VKo4HmNp5LzOlOr+SwUXGx3WsLRUVTxE7RI7kIRKoVs=";
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
    };
}
