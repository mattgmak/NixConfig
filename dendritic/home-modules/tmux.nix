{
  flake.homeModules.tmux =
    { pkgs, hostname, ... }:
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
          bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-on \; send -X begin-selection
        '';
        plugins = with pkgs.tmuxPlugins; [
          sensible
          yank
          {
            plugin = resurrect;
            extraConfig = ''
              set -g @resurrect-strategy-nvim 'session'
            '';
          }
          {
            plugin = continuum;
            extraConfig = ''
              set -g @continuum-restore 'on'
              set -g @continuum-boot 'on'
            '';
          }
          {
            plugin = catppuccin;
            extraConfig = ''
              # set -g @catppuccin_flavor 'mocha'
              set -g @catppuccin_status_background "none"

              set -g @catppuccin_window_status_style "custom"
              set -g @catppuccin_window_left_separator "#[bg=default,fg=#{@thm_surface_0}]#[bg=#{@thm_overlay_2},fg=#{@thm_surface_0}]"
              # set -g @catppuccin_window_middle_separator "#[bg=#{@thm_surface_0},fg=#{@thm_overlay_2}]"
              set -g @catppuccin_window_middle_separator ""
              set -g @catppuccin_window_right_separator "#[bg=default,fg=#{@thm_overlay_2}]"
              set -g @catppuccin_window_text "#W "
              set -g @catppuccin_window_number "#I"

              set -g @catppuccin_window_current_left_separator "#[bg=default,fg=#{@thm_surface_1}]"
              # set -g @catppuccin_window_current_middle_separator "#[bg=#{@thm_surface_1},fg=#{@thm_mauve}]#[bg=#{@thm_mauve},fg=#{@thm_bg}]"
              set -g @catppuccin_window_current_middle_separator ""
              set -g @catppuccin_window_current_right_separator "#[bg=default,fg=#{@thm_mauve}]"
              set -g @catppuccin_window_number_position "right"
              set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),} "
              set -g @catppuccin_window_current_number "#I"

              set -g @catppuccin_status_left_separator  " "
              # set -g @catppuccin_status_middle_separator "#[bg=#{@thm_surface_0}]"
              set -g @catppuccin_status_middle_separator ""
              set -g @catppuccin_status_right_separator " "
              set -g @catppuccin_status_fill "icon"
              set -g @catppuccin_status_connect_separator "no"
              set -g status-left-length 100
              set -g status-right-length 100
              set -g status-left "#{E:@catppuccin_status_session}"
              set -g status-right "#{E:@catppuccin_status_directory}#{E:@catppuccin_status_application}#{E:@catppuccin_status_date_time}"
              set -g @catppuccin_directory_text " #{b:pane_current_path}"
              set -g @catppuccin_directory_icon "󰉋 "
              set -g @catppuccin_date_time_text " %H:%M"
            '';
          }
          {
            plugin = tmux-sessionx;
            extraConfig = ''
              set -g @sessionx-bind-zo-new-window 'ctrl-y'
              set -g @sessionx-auto-accept 'off'
              set -g @sessionx-bind 'o'
              set -g @sessionx-window-height '85%'
              set -g @sessionx-window-width '75%'
              set -g @sessionx-zoxide-mode 'on'
              set -g @sessionx-custom-paths-subdirectories 'false'
              set -g @sessionx-filter-current 'false'
            '';
          }
          # {
          #   plugin = tmux-floax;
          #   extraConfig = ''
          #     set -g @floax-width '80%'
          #     set -g @floax-height '80%'
          #     set -g @floax-border-color 'magenta'
          #     set -g @floax-text-color 'blue'
          #     set -g @floax-bind 'p'
          #     set -g @floax-change-path 'true'
          #   '';
          # }
          tmux-fzf
          fzf-tmux-url
          {
            plugin = fuzzback;
            extraConfig = ''
              set -g @fuzzback-bind j
              set -g @fuzzback-popup 1
              set -g @fuzzback-popup-size '90%'
            '';
          }
        ];
      };
    }
    // (
      if hostname != "Droid" then
        {
          stylix.targets.tmux.enable = false;
        }
      else
        { }
    );
}
