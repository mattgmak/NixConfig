{
  flake.homeModules.atuin =
    {
      lib,
      hostname,
      username,
      ...
    }:
    let
      acceptShiftShortcuts = lib.listToAttrs (
        map (n: {
          name = "ctrl-shift-${toString n}";
          value = "accept-${toString n}";
        }) (lib.range 1 9)
      );
    in
    {
      programs.atuin = {
        enable = true;
        daemon.enable = hostname != "Droid" && username != "root" && hostname != "MacMini";
        enableBashIntegration = false;
        settings = {
          ctrl_n_shortcuts = true;
          exit_mode = "return-query";
          invert = true;
          enter_accept = true;
          keymap = {
            emacs = acceptShiftShortcuts // {
              "ctrl-d" = "delete";
              "ctrl-y" = "copy";
            };
            vim-normal = acceptShiftShortcuts // {
              "ctrl-d" = "delete";
              "ctrl-y" = "copy";
            };
          };
        };
      };
    };
}
