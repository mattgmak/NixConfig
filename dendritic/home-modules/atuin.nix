{
  flake.homeModules.atuin =
    {
      lib,
      hostname,
      config,
      ...
    }:
    let
      digitShortcuts = lib.listToAttrs (
        map (n: {
          name = "ctrl-shift-${toString n}";
          value = "return-selection-${toString n}";
        }) (lib.range 1 9)
      );
    in
    {
      programs.atuin = {
        enable = true;
        daemon.enable = hostname != "Droid" && config.home.username != "root" && hostname != "MacMini";
        enableBashIntegration = false;
        settings = {
          ctrl_n_shortcuts = true;
          exit_mode = "return-query";
          invert = true;
          enter_accept = true;
          # Never record `pi "..."` prompt launches (applies at record time via
          # History::should_save, both local and daemon paths).
          history_filter = [
            "^pi \"" # pi launched with a double-quoted prompt
            "^pi '" # pi launched with a single-quoted prompt
            # commands re-run from the atuin search keybinding carry a leading
            # `# <uuid>` marker line (see `atuin init nu`) — skip those too
            "(?m)^# [0-9a-f-]{36}$"
          ];
          # zsh's default keymap is viins, so atuin's viins widgets start the TUI
          # with --keymap-mode=vim-insert; overrides for emacs/vim-normal alone
          # never apply there.
          # return-selection-N (not accept-N) puts the entry on the command line
          # for editing instead of executing it.
          keymap = {
            emacs = digitShortcuts // {
              "ctrl-d" = "delete";
              "ctrl-y" = "copy";
            };
            vim-normal = digitShortcuts // {
              "ctrl-d" = "delete";
              "ctrl-y" = "copy";
            };
            vim-insert = digitShortcuts // {
              "ctrl-d" = "delete";
              "ctrl-y" = "copy";
            };
          };
        };
      };
    };
}
