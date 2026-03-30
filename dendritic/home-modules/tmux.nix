{
  flake.homeModules.tmux =
    {
      pkgs,
      hostname,
      config,
      lib,
      ...
    }:
    {
      # Required by programs.sesh enableTmuxIntegration (home-manager modules/programs/sesh.nix)
      programs.fzf = {
        enable = true;
        tmux.enableShellIntegration = true;
      };

      programs.sesh = {
        enable = true;
        tmuxKey = "g";
        enableAlias = false; # Use my own
        settings = {
          cache = false;
          blacklist = [
            "scratch"
          ];
          dir_length = 2;
          separator_aware = true;
        };
      };

      # sesh tmux bind uses fd for ctrl-f find mode (not added by programs.sesh)
      home.packages = [
        pkgs.fd
      ];

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
          set -g allow-passthrough on
          set -ga update-environment TERM
          set -ga update-environment TERM_PROGRAM
          bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-on \; send -X begin-selection
          bind-key c new-window -c "#{pane_current_path}"
          bind-key % split-window -h -c "#{pane_current_path}"
          bind-key '"' split-window -v -c "#{pane_current_path}"

          bind-key x kill-pane # skip "kill-pane 1? (y/n)" prompt
          set -g detach-on-destroy off  # don't exit from tmux when closing a session

          bind-key -N "sesh: last session" o run-shell "${lib.getExe config.programs.sesh.package} last"
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

              set -g @catppuccin_status_left_separator  ""
              # set -g @catppuccin_status_middle_separator "#[bg=#{@thm_surface_0}]"
              set -g @catppuccin_status_middle_separator ""
              set -g @catppuccin_status_right_separator ""
              set -g @catppuccin_status_fill "icon"
              set -g @catppuccin_status_connect_separator "no"
              set -g status-left-length 100
              set -g status-right-length 100
              set -g status-left "#{E:@catppuccin_status_session} "
              set -g status-right "#{E:@catppuccin_status_directory} #{E:@catppuccin_status_application} #{E:@catppuccin_status_date_time}"
              set -g @catppuccin_directory_text " #{b:pane_current_path}"
              set -g @catppuccin_directory_icon "󰉋 "
              set -g @catppuccin_date_time_text " %H:%M"
            '';
          }
          {
            plugin = tmux-floax;
            extraConfig = ''
              set -g @floax-width '80%'
              set -g @floax-height '80%'
              set -g @floax-border-color 'magenta'
              set -g @floax-text-color 'white'
              set -g @floax-bind 't'
              set -g @floax-bind-menu 'T'
              set -g @floax-change-path 'true'
            '';
          }
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
          {
            plugin = better-mouse-mode;
            extraConfig = ''
              set -g @scroll-speed-num-lines-per-scroll '1'
              set -g @emulate-scroll-for-no-mouse-alternate-buffer 'on'
            '';
          }
          {
            plugin = jump;
            extraConfig =
              let
                decRgbToEsc =
                  baseName: prefix:
                  let
                    c = (config.lib.stylix or { }).colors or { };
                    to255 = ch: builtins.floor ((builtins.fromJSON (c.${"${baseName}-dec-${ch}"} or "0")) * 255);
                    r = to255 "r";
                    g = to255 "g";
                    b = to255 "b";
                  in
                  "${prefix}${toString r};${toString g};${toString b}m";
                stylixColors = (config.lib.stylix or { }).colors or { };
                # jumpBgColor =
                #   if stylixColors != { } then "\\e[0m" + (decRgbToEsc "base02" "\\e[48;2;") else "\\e[0m\\e[90m";
                jumpBgColor = "\\e[0m";
                jumpFgColor = if stylixColors != { } then (decRgbToEsc "base08" "\\e[38;2;") else "\\e[1m\\e[31m";
              in
              ''
                set -g @jump-key 'Bspace'
                set -g @jump-bg-color '${jumpBgColor}'
                set -g @jump-fg-color '${jumpFgColor}'
              '';
          }
        ];
      };
    }
    // lib.optionalAttrs (hostname != "Droid") {
      stylix.targets.tmux.enable = false;
    };
}
