{ ... }:
let
in {
  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 14;
      font-family = "IosevkaTerm Nerd Font";
      quick-terminal-position = "center";
      keybind = [
        "ctrl+shift+page_up=move_tab:-1"
        "ctrl+shift+page_down=move_tab:1"
        "global:super+t=toggle_quick_terminal"
      ];
    };
  };
}
