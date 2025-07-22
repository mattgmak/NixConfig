{ pkgs, ... }: {
  programs.ghostty = {
    # Only enable on Linux for now, install ghostty on macOS with brew
    enable = pkgs.stdenv.isLinux;
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
