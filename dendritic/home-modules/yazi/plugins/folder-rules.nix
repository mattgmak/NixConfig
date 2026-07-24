{
  flake.yaziPluginFolderRules =
    { lib, stdenv }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-folder-rules";
      version = "unstable-2026-07-24";

      src = ./folder-rules;

      installPhase = ''
        mkdir -p $out/share/yazi/plugins/folder-rules
        cp -r $src/* $out/share/yazi/plugins/folder-rules/
      '';

      meta = with lib; {
        description = "Per-folder sort rules for Yazi";
        homepage = "https://yazi-rs.github.io/docs/tips/#folder-rules";
        license = licenses.mit;
        maintainers = [ ];
        platforms = platforms.all;
      };
    };
}
