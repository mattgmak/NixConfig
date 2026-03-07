{
  flake.homeModules.lazygit =
    { pkgs, lib, ... }:
    {
      programs.lazygit = {
        enable = true;
        settings = {
          # Use my own
          enableNushellIntegration = lib.mkForce false;
          shellWrapperName = "lgg";
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
          os = {
            open = if pkgs.stdenv.isDarwin then "open {{filename}}" else "xdg-open {{filename}}";
            openLink = if pkgs.stdenv.isDarwin then "open {{link}}" else "xdg-open {{link}}";
          };
        };
      };
    };
}
