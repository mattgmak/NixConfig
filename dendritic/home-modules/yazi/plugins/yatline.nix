{
  flake.yaziPluginYatline =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-yatline";
      version = "0.5.1";

      # nixpkgs pins v0.5.0, which calls the yazi APIs it deprecated:
      # `Url.is_search` and `File:icon()`. v0.5.1 uses `Url.spec.is_search` and
      # `th.icon:match`, so it runs without deprecation popups.
      # TODO: drop this file when nixpkgs carries v0.5.1 and inherit from pkgs.yaziPlugins.
      src = fetchFromGitHub {
        owner = "imsi32";
        repo = "yatline.yazi";
        rev = "dc44b737791c07a8e2de54d8838cfe304853d780";
        hash = "sha256-U7MAZSc0iPiRvLZM8tKbNd749pblarB1Y48lH13uLuU=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Yazi plugin that replaces the header line and the status line";
        homepage = "https://github.com/imsi32/yatline.yazi";
        license = licenses.mit;
        maintainers = [ "imsi32" ];
        platforms = platforms.all;
      };
    };
}
