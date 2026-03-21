{
  flake.homeModules.atuin =
    { hostname, username, ... }:
    {
      programs.atuin = {
        enable = true;
        daemon.enable = hostname != "Droid" && username != "root";
        settings = {
          exit_mode = "return-query";
          invert = true;
          enter_accept = true;
          keymap = {
            emacs."ctrl-y" = "copy";
            vim-normal."ctrl-y" = "copy";
          };
          # keymap.prefix =
          #   let
          #     commandSlots = lib.map (index: toString index) (lib.range 1 9);
          #     acceptList = lib.map (index: {
          #       name = "${index}";
          #       value = "accept-${index}";
          #     }) commandSlots;
          #     returnSelectionList = lib.map (index: {
          #       name = "ctrl-${index}";
          #       value = "return-selection-${index}";
          #     }) commandSlots;
          #   in
          #   builtins.listToAttrs (acceptList ++ returnSelectionList);
          # keymap.emacs =
          #   let
          #     commandSlots = lib.map (index: toString index) (lib.range 1 9);
          #     acceptList = lib.map (index: {
          #       name = "ctrl-${index}";
          #       value = "accept-${index}";
          #     }) commandSlots;
          #     returnSelectionList = lib.map (index: {
          #       name = "ctrl-shift-${index}";
          #       value = "return-selection-${index}";
          #     }) commandSlots;
          #   in
          #   builtins.listToAttrs (acceptList ++ returnSelectionList);
        };
      };
    };
}
