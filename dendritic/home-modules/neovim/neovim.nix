{
  flake.homeModules.neovim =
    { pkgs, ... }:
    {
      # home.file = {
      #   ".config/nvim" = {
      #     source = ./config;
      #     recursive = true;
      #   };
      # };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        extraLuaConfig = ''
          ${builtins.readFile ./config/lua/plugins.lua}
          ${builtins.readFile ./config/lua/config.lua}
        '';
        extraPackages = with pkgs; [
          gcc
          tree-sitter
        ];
      };
      home.packages = with pkgs; [
        tree-sitter
      ];
    };
}
