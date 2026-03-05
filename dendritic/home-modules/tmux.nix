{
  flake.homeModules.tmux =
    { pkgs, ... }:
    {
      programs.tmux = {
        enable = true;
        mouse = true;
        keyMode = "vi";
        terminal = "tmux-256color";
        clock24 = true;
        sensibleOnTop = true;
        baseIndex = 1;
        escapeTime = 0;
        extraConfig = ''
          set -g renumber-windows on
          set -g detach-on-destroy off
          set -g set-clipboard on
          set -g status-position top
          set -g pane-active-border-style 'fg=magenta,bg=default'
          set -g pane-border-style 'fg=brightblack,bg=default'
          # set -g @floax-width '80%'
          # set -g @floax-height '80%'
          # set -g @floax-border-color 'magenta'
          # set -g @floax-text-color 'blue'
          # set -g @floax-bind 'p'
          # set -g @floax-change-path 'true'
          set -g @sessionx-bind-zo-new-window 'ctrl-y'
          set -g @sessionx-auto-accept 'off'
          set -g @sessionx-bind 'o'
          set -g @sessionx-window-height '85%'
          set -g @sessionx-window-width '75%'
          set -g @sessionx-zoxide-mode 'on'
          set -g @sessionx-custom-paths-subdirectories 'false'
          set -g @sessionx-filter-current 'false'
          set -g @continuum-restore 'on'
          set -g @resurrect-strategy-nvim 'session'
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_number_position "right"
          set -g @catppuccin_window_text "#W"
          set -g @catppuccin_window_number "#I"
          set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator " "
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"
          set -g status-left-length 100
          set -g status-right-length 100
          set -g status-left "#{E:@catppuccin_status_session}"
          set -g status-right "#{E:@catppuccin_status_directory}"
          set -g @catppuccin_directory_text "#{b:pane_current_path}"
        '';
        plugins = with pkgs.tmuxPlugins; [
          sensible
          yank
          resurrect
          continuum
          catppuccin
          tmux-sessionx
          # tmux-floax
          tmux-fzf
          fzf-tmux-url
          tmux-thumbs
        ];
      };
      stylix.targets.tmux.enable = false;
    };
}
