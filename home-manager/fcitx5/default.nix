{ pkgs, ... }: {

  home.file = { ".config/fcitx5/config".source = ./config/config; };
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-rime
      fcitx5-chinese-addons
      fcitx5-pinyin-zhwiki
      fcitx5-gtk
      fcitx5-rose-pine
    ];
  };
}
