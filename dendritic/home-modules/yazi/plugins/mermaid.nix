{
  flake.yaziPluginMermaid =
    { lib, stdenv, fetchFromGitHub }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-mermaid";
      version = "0.3.1";

      # nixpkgs carries no mermaid.yazi package, so this file holds the source.
      src = fetchFromGitHub {
        owner = "passion0102";
        repo = "mermaid.yazi";
        rev = "b46d539bf5c0c9c3dee1967bce7aa6515ef71a84";
        hash = "sha256-313d3Z/idPZzeYHE/5ztWShOgrrfgyclLNAuvMH+tEc=";
      };

      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
      '';

      meta = with lib; {
        description = "Yazi plugin that renders Mermaid diagrams in Markdown previews";
        homepage = "https://github.com/passion0102/mermaid.yazi";
        license = licenses.mit;
        maintainers = [ "passion0102" ];
        platforms = platforms.all;
      };
    };
}
