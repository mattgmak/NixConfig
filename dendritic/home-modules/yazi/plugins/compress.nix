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
      version = "unstable-2026-05-15";

      src = fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "e60e122e565e7c4798ef22767eb363428dc6704e";
        hash = "sha256-yts/LCDpCH9cH1pY6Im/UpCQDCyzjhSGDZfGpQDdEZc=";
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
