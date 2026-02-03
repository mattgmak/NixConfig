{
  flake.yaziPluginFg =
    {
      lib,
      stdenv,
      fzf,
      ripgrep,
      bat,
    }:

    stdenv.mkDerivation {
      pname = "yaziPlugins-fg";
      version = "unstable-2025-07-22";

      # src = fetchgit {
      #   url = "https://gitee.com/DreamMaoMao/fg.yazi.git";
      #   rev = "0c6ae0b52a0aa40bb468ca565c34ac413d1f93c1";
      #   hash = "sha256-pFljxXAyUfu680+MhbLrI07RcukrPXgmIvtp3f6ZVvY=";
      # };

      src = ./fg;

      buildInputs = [
        fzf # Required dependency
        ripgrep # Required dependency
        bat # Required dependency
      ];

      installPhase = ''
        mkdir -p $out/share/yazi/plugins/fg
        cp -r $src/* $out/share/yazi/plugins/fg/
        chmod -R +x $out/share/yazi/plugins/fg/
      '';

      meta = with lib; {
        description = "Fuzzy finder plugin for Yazi file manager";
        homepage = "https://gitee.com/DreamMaoMao/fg.yazi";
        license = licenses.mit;
        maintainers = [ ];
        platforms = platforms.all;
      };
    };
}
