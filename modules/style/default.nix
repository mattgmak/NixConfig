{ pkgs, ... }: {
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka-term
    inter
    noto-fonts-cjk-serif
    noto-fonts-emoji
  ];

  stylix.targets.gnome-text-editor.enable = false;

  stylix = {
    enable = true;
    polarity = "dark";
    # rebecca, paraiso, mellow-purple
    base16Scheme =
      "${pkgs.base16-schemes}/share/themes/tokyodark-terminal.yaml";
    image = ./beautiful-mountains-landscape.jpg;
    cursor = pkgs.lib.mkIf pkgs.stdenv.isLinux {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka-term;
        name = "IosevkaTerm Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts-cjk-sans;
        name = "Noto Sans CJK HK";
      };
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

}
