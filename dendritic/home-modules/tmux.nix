{
  flake.homeModules.tmux = {
    programs.tmux = {
      enable = true;
      mouse = true;
      keyMode = "vi";
      terminal = "screen-256color";
      clock24 = true;
      sensibleOnTop = true;
    };
  };
}
