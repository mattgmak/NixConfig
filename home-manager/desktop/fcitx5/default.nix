{ pkgs, ... }: {

  home.file = { ".config/fcitx5/config".source = ./config/config; };
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      # fcitx5-with-addons = pkgs.kdePackages.fcitx5-with-addons;
      addons = with pkgs; [
        fcitx5-rime
        qt6Packages.fcitx5-chinese-addons
        fcitx5-pinyin-zhwiki
        fcitx5-gtk
        fcitx5-rose-pine
      ];
    };
  };
}
