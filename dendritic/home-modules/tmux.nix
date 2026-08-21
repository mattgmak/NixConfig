{ inputs, ... }:
{
  flake.homeModules.tmux =
    {
      pkgs,
      hostname,
      config,
      lib,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      powerkitPluginsDir = ./tmux/powerkit/plugins;

      mkTmuxPowerkitTheme =
        colors:
        let
          c = colors.withHashtag;
          hex = name: c.${name} or "#000000";
        in
        ''
          # stylix theme — session-bg=base0D (blue), window-active=base0E (purple)
          #!/usr/bin/env bash
          declare -gA THEME_COLORS=(
            [background]="${hex "base00"}"
            [statusbar-bg]="${hex "base01"}"
            [statusbar-fg]="${hex "base05"}"

            [session-bg]="${hex "base0D"}"
            [session-fg]="${hex "base00"}"
            [session-prefix-bg]="${hex "base0A"}"
            [session-copy-bg]="${hex "base0C"}"
            [session-search-bg]="${hex "base09"}"
            [session-command-bg]="${hex "base0F"}"

            [window-active-base]="${hex "base0E"}"
            [window-active-style]="bold"
            [window-inactive-base]="${hex "base02"}"
            [window-inactive-style]="none"
            [window-activity-style]="italics"
            [window-bell-style]="bold"
            [window-zoomed-bg]="${hex "base0C"}"

            [pane-border-active]="${hex "base0D"}"
            [pane-border-inactive]="${hex "base03"}"

            [ok-base]="${hex "base03"}"
            [good-base]="${hex "base0B"}"
            [info-base]="${hex "base0D"}"
            [warning-base]="${hex "base0A"}"
            [error-base]="${hex "base08"}"
            [disabled-base]="${hex "base04"}"

            [message-bg]="${hex "base01"}"
            [message-fg]="${hex "base05"}"

            [popup-bg]="${hex "base01"}"
            [popup-fg]="${hex "base05"}"
            [popup-border]="${hex "base0E"}"
            [menu-bg]="${hex "base01"}"
            [menu-fg]="${hex "base05"}"
            [menu-selected-bg]="${hex "base0E"}"
            [menu-selected-fg]="${hex "base00"}"
            [menu-border]="${hex "base0E"}"
          )
        '';

      stylixColors = (config.lib.stylix or { }).colors or { };
      hexOr =
        name: fallback:
        if stylixColors != { } then stylixColors.withHashtag.${name} or fallback else fallback;
      sessionBgHex = hexOr "base0D" "#6bb8ff";
      sessionPrefixHex = hexOr "base0A" "#ff9470";
      sessionCopyHex = hexOr "base0C" "#8af5ff";
      sessionSearchHex = hexOr "base09" "#ffc387";
      sessionCommandHex = sessionBgHex;
      accentHex = hexOr "base0E" "#cba6f7";

      tmuxPowerkitBase = inputs.tmux-powerkit.packages.${system}.default;
      tmuxPowerkitRoot = "${tmuxPowerkitBase}/share/tmux-plugins/tmux-powerkit";
      tmuxPowerkitSrc = pkgs.runCommand "tmux-powerkit-src" { } ''
        cp -R ${tmuxPowerkitRoot}/. $out/
        chmod -R u+w $out/src/plugins $out/src/renderer $out/src/core $out/bin
        install -Dm755 ${powerkitPluginsDir}/directory.sh $out/src/plugins/directory.sh
        install -Dm755 ${powerkitPluginsDir}/pane_application.sh $out/src/plugins/pane_application.sh
        # Patched: pill caps, session mode, format-native escape, render cache TTL
        ${pkgs.python3}/bin/python3 ${./tmux/powerkit/patches/apply.py} $out
      '';
      tmuxPowerkit = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "tmux-powerkit";
        version = tmuxPowerkitBase.version;
        src = tmuxPowerkitSrc;
        rtpFilePath = "tmux-powerkit.tmux";
      };

      tmuxPowerkitThemeFile = pkgs.writeTextFile {
        name = "tmux-powerkit-stylix-theme.sh";
        text = mkTmuxPowerkitTheme stylixColors;
      };
    in
    {
      imports = [ inputs.agent-sesh.homeModules.agent-sesh ];

      programs.agent-sesh = {
        enable = true;
        tmuxKey = "a";
        popupWidth = "90%";
        popupHeight = "90%";
      };

      # Required by programs.sesh enableTmuxIntegration (home-manager modules/programs/sesh.nix)
      programs.fzf = {
        enable = true;
        enableNushellIntegration = false;
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
        pkgs.bash
      ];

      home.file.".config/tmux-powerkit/themes/stylix.sh".source = tmuxPowerkitThemeFile;

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
          set -g allow-passthrough on
          set -g visual-activity off
          set -g focus-events on
          set -ga update-environment TERM
          set -ga update-environment TERM_PROGRAM
          bind r run-shell 'rm -rf ${config.home.homeDirectory}/.cache/tmux-powerkit/data/* 2>/dev/null; true' \; source-file ~/.config/tmux/tmux.conf \; refresh-client -S \; display-message "Config reloaded (powerkit cache cleared)..."
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-on \; send -X begin-selection
          bind-key c new-window -c "#{pane_current_path}"
          bind-key % split-window -h -c "#{pane_current_path}"
          bind-key '"' split-window -v -c "#{pane_current_path}"

          bind-key C-h select-pane -L
          bind-key C-j select-pane -D
          bind-key C-k select-pane -U
          bind-key C-l select-pane -R

          bind-key x kill-pane # skip "kill-pane 1? (y/n)" prompt
          set -g detach-on-destroy off  # don't exit from tmux when closing a session

          bind-key -N "sesh: last session" o run-shell "${lib.getExe config.programs.sesh.package} last"

          # Redraw status on pane/cwd change (format-native cwd/app plugins)
          set-hook -g pane-focus-in 'refresh-client -S'
          set-hook -g client-focus-in 'refresh-client -S'
          set-hook -g after-select-pane 'refresh-client -S'
          set-hook -g pane-directory-changed 'refresh-client -S'

          # Enable support for advanced keyboard shortcuts (like Ctrl+.)
          set -g extended-keys on
          set -as terminal-features 'xterm*:extkeys'
          set -g extended-keys-format csi-u
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
              # set -g @continuum-boot 'on'
            '';
          }
          {
            plugin = tmuxPowerkit;
            extraConfig = ''
              set -g @powerkit_status_order "session,plugins"
              set -g @powerkit_plugins "directory,pane_application,datetime"
              set -g @powerkit_theme "custom"
              set -g @powerkit_custom_theme_path "${config.home.homeDirectory}/.config/tmux-powerkit/themes/stylix.sh"
              set -g @powerkit_transparent "true"
              set -g @powerkit_separator_style "rounded"
              set -g @powerkit_edge_separator_style "rounded:all"
              set -g @powerkit_elements_spacing "false"
              set -g @powerkit_inactive_window_fg "${hexOr "base05" "#ffffff"}"
              set -g @powerkit_status_position "top"
              set -g @powerkit_status_interval "1"
              set -g @powerkit_session_normal_color "${sessionBgHex}"
              set -g @powerkit_session_prefix_color "${sessionPrefixHex}"
              set -g @powerkit_session_copy_mode_color "${sessionCopyHex}"
              set -g @powerkit_session_show_mode "true"
              set -g @powerkit_session_prefix_icon ""
              set -g @powerkit_session_copy_icon ""
              set -g @powerkit_session_search_icon ""
              set -g @powerkit_session_command_icon ""
              set -g @powerkit_active_window_title "#W "
              set -g @powerkit_inactive_window_title "#W "
              set -g @powerkit_zoomed_window_icon "󮁁"
              set -g @powerkit_plugin_datetime_format "time"
              set -g @powerkit_plugin_directory_icon "󰉋"
              set -g @powerkit_plugin_pane_application_icon ""
            '';
          }
          {
            plugin = tmux-floax;
            extraConfig = ''
              set -g @floax-width '80%'
              set -g @floax-height '80%'
              set -g @floax-border-color '${accentHex}'
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
                    to255 =
                      ch: builtins.floor ((builtins.fromJSON (c.${"${baseName}-dec-${ch}"} or "0")) * 255);
                    r = to255 "r";
                    g = to255 "g";
                    b = to255 "b";
                  in
                  "${prefix}${toString r};${toString g};${toString b}m";
                jumpBgColor = "\\e[0m";
                jumpFgColor =
                  if stylixColors != { } then (decRgbToEsc "base08" "\\e[38;2;") else "\\e[1m\\e[31m";
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
