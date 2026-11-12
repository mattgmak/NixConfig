{
  flake.yaziPluginYatlineTabPath =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-tab-path";
      version = "unstable-2025-02-25";

      src = fetchFromGitHub {
        owner = "blackdaemon";
        repo = "yatline-tab-path.yazi";
        rev = "101fe7c8a979dbdf498259cc773dc8bd781a8733";
        hash = "sha256-wV5YXm31zMsG7e/YhWa+72eLYC/QmBgjweKFuIn5BpA=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Yatline addon that colorizes the tab path section";
        homepage = "https://github.com/blackdaemon/yatline-tab-path.yazi";
        license = licenses.mit;
        maintainers = [ "blackdaemon" ];
        platforms = platforms.all;
      };
    };
}
