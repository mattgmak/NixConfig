{
  flake.yaziPluginSystemClipboard =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-system-clipboard";
      version = "unstable-2026-08-29";

      src = fetchFromGitHub {
        owner = "orhnk";
        repo = "system-clipboard.yazi";
        rev = "ed946c3932937cb58b1bcaaf0e45f8e26b14f151";
        hash = "sha256-1qbi/oOcnWTliP+FT4Yk4rwPCRu4KQh3EHJzLY+noUw=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Copy the selected files to the system clipboard through cb";
        homepage = "https://github.com/orhnk/system-clipboard.yazi";
        license = licenses.mit;
        maintainers = [ "orhnk" ];
        platforms = platforms.all;
      };
    };
}
