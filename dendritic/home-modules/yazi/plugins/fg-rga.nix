{
  flake.yaziPluginFgRga =
    {
      lib,
      stdenv,
      fzf,
      ripgrep-all,
      bat,
    }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-fg-rga";
      version = "unstable-2025-03-15";

      src = ./fg-rga;

      buildInputs = [
        fzf
        ripgrep-all
        bat
      ];

      installPhase = ''
        mkdir -p $out/share/yazi/plugins/fg-rga
        cp -r $src/* $out/share/yazi/plugins/fg-rga/
        chmod -R +x $out/share/yazi/plugins/fg-rga/
      '';

      meta = with lib; {
        description = "Fuzzy finder plugin for Yazi using rga (ripgrep-all) to search in PDFs, archives, and more";
        homepage = "https://github.com/phiresky/ripgrep-all";
        license = licenses.mit;
        maintainers = [ ];
        platforms = platforms.all;
      };
    };
}
