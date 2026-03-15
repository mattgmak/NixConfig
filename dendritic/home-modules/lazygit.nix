{
  flake.homeModules.lazygit =
    { pkgs, lib, ... }:
    {
      programs.lazygit = {
        enable = true;
        # Use my own
        enableNushellIntegration = false;
        settings = {
          keybinding = {
            # universal = {
            # };
          };
          gui = {
            scrollHeight = 10;
          };
          git = {
            pagers = [
              {
                colorArg = "always";
                pager = "delta --paging=never --line-numbers --hunk-header-style=omit";
              }
            ];
          };
          os =
            let
              cursorOpenCmd = "nu ~/.config/yazi/scripts/cursor-open.nu";
            in
            {
              open = if pkgs.stdenv.isDarwin then "open {{filename}}" else "xdg-open {{filename}}";
              openLink = if pkgs.stdenv.isDarwin then "open {{link}}" else "xdg-open {{link}}";
              edit = "${cursorOpenCmd} {{filename}}";
              editAtLine = "${cursorOpenCmd} {{filename}}:{{line}}";
              editAtLineAndWait = "${cursorOpenCmd} {{filename}}:{{line}}";
              editInTerminal = false;
              openDirInEditor = "${cursorOpenCmd} {{dir}}";
            };
        };
      };
    };
}
