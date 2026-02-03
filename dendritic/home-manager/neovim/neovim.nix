{
  flake.homeModules.neovim =
    { pkgs, ... }:
    {
      home.file = {
        ".config/nvim" = {
          source = ./config;
          recursive = true;
        };
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        extraPackages = with pkgs; [
          gcc
          tree-sitter
        ];
      };
    };
}
