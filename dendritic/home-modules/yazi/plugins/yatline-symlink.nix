{
  flake.yaziPluginYatlineSymlink =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-symlink";
      version = "unstable-2026-06-02";

      src = fetchFromGitHub {
        owner = "lpanebr";
        repo = "yazi-plugins";
        rev = "ea50bee8ee4343b026800a8237ce4b2a1eb55dac";
        hash = "sha256-zO8HfQWYNadwD1n+g90smjtYiymF264p9dZsgKKcyRM=";
      };

      # The repo is a monorepo, so only the requested plugin goes into $out.
      installPhase = ''
        mkdir -p $out
        cp -r $src/yatline-symlink.yazi/* $out/
      '';

      meta = with lib; {
        description = "Yatline addon that shows the target of a symlink";
        homepage = "https://github.com/lpanebr/yazi-plugins/tree/main/yatline-symlink.yazi";
        license = licenses.mit;
        maintainers = [ "lpanebr" ];
        platforms = platforms.all;
      };
    };
}
