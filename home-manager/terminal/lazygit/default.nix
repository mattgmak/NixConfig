{ config, ... }: {
  programs.lazygit = { enable = true; };
  home.file.".config/lazygit/config.yml".text = ''
    keybindings:
      nextItem-alt: k
      prevItem-alt: j
      scrollDownMain-alt1: K
      scrollUpMain-alt1: J
  '';
}
