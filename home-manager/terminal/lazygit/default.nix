{ config, ... }: {
  programs.lazygit = { enable = true; };
  stylix.targets.lazygit.enable = false;
  home.file.".config/lazygit/config.yml".text = ''
    gui:
      theme:
        activeBorderColor:
        - '#${config.lib.stylix.colors.base0E}'
        - bold
        cherryPickedCommitBgColor:
        - '#383a62'
        cherryPickedCommitFgColor:
        - '#666699'
        defaultFgColor:
        - '#f1eff8'
        inactiveBorderColor:
        - '#a0a0c5'
        optionsTextColor:
        - '#${config.lib.stylix.colors.base0B}'
        searchingActiveBorderColor:
        - '#${config.lib.stylix.colors.base0E}'
        - bold
        selectedLineBgColor:
        - '#666699'
        unstagedChangesColor:
        - '#a0a0c5'
    keybindings:
      nextItem-alt: k
      prevItem-alt: j
      scrollDownMain-alt1: K
      scrollUpMain-alt1: J
  '';
}
