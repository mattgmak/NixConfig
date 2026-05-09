{ inputs, ... }:
{
  flake.homeModules.neovim =
    { pkgs, ... }:
    let
      treesitterPkg = inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home.file = {
        ".config/nvim/after" = {
          source = ./config/lua/after;
          recursive = true;
        };
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        withRuby = true;
        initLua = ''
          ${builtins.readFile ./config/lua/plugins.lua}
          ${builtins.readFile ./config/lua/config.lua}
        '';
        extraPackages = with pkgs; [
          lua-language-server
          gcc
          treesitterPkg
        ];
      };
      home.packages = [
        treesitterPkg
      ];
    };
}
