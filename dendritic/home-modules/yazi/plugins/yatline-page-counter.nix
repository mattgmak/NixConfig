{
  flake.yaziPluginYatlinePageCounter =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-page-counter";
      version = "unstable-2025-09-24";

      src = fetchFromGitHub {
        owner = "PepeRoConde";
        repo = "yatline-page-counter.yazi";
        rev = "12f7c942f21f2fdeee6949c942c33b92dea000d1";
        hash = "sha256-xrJYDpJi+UsQu6Z799+EFCWX6OBBwyim5y7Tz3Zag7Q=";
      };

      # Upstream bug: `hovered()` is a global, so loading this addon overwrites
      # the same global from the other yatline addons and breaks their hovered
      # checks. The upstream version returns "", which is truthy in Lua.
      # TODO: drop when upstream scopes the helper local.
      patchPhase = ''
        sed -i "s/^function hovered()/local function hovered()/" main.lua
      '';

      installPhase = ''
        mkdir -p $out
        cp -r ./* $out/
      '';

      meta = with lib; {
        description = "Yatline addon for the page count of documents";
        homepage = "https://github.com/PepeRoConde/yatline-page-counter.yazi";
        license = licenses.mit;
        maintainers = [ "PepeRoConde" ];
        platforms = platforms.all;
      };
    };
}
