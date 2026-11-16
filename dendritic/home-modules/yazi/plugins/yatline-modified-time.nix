{
  flake.yaziPluginYatlineModifiedTime =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline-modified-time";
      version = "unstable-2025-09-04";

      src = fetchFromGitHub {
        owner = "wekauwau";
        repo = "yatline-modified-time.yazi";
        rev = "2d334719fc24ca034e46affb05187bcb2ee55225";
        hash = "sha256-sus3GNM6CEfL5AmhJfRLT56MH3+xU20vcIfW9+C1RLg=";
      };

      # Upstream bug: `hovered()` is a global that returns "" when no file is
      # hovered, so `h or h.cha.mtime` indexes a string and the yatline render
      # blanks the whole UI in an empty directory. Scope it local and guard it.
      # TODO: drop when upstream fixes wekauwau/yatline-modified-time.yazi.
      patchPhase = ''
        sed -i -e 's/^function hovered(/local function hovered(/' \
          -e 's/return ""/return nil/' \
          -e 's/if h or h.cha.mtime then/if h and h.cha.mtime then/' main.lua
      '';

      installPhase = ''
        mkdir -p $out
        cp -r ./* $out/
      '';

      meta = with lib; {
        description = "Yatline addon for the modification time of the hovered file";
        homepage = "https://github.com/wekauwau/yatline-modified-time.yazi";
        license = licenses.mit;
        maintainers = [ "wekauwau" ];
        platforms = platforms.all;
      };
    };
}
