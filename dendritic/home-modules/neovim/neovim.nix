{ inputs, ... }:
{
  flake.homeModules.neovim =
    { config, pkgs, ... }:
    let
      treesitterPkg = inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default;
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      neovimRoot = "${repoRoot}/home-modules/neovim";
    in
    {
      home.file = {
        ".config/nvim/lua/plugins.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua/plugins.lua";
        ".config/nvim/lua/config.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua/config.lua";
        ".config/nvim/after".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua/after";
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        withRuby = true;
        initLua = ''
          require('plugins')
          require('config')
        '';
        extraPackages = with pkgs; [
          lua-language-server
          nixd
          gcc
          gnumake
          ripgrep
          fd
          treesitterPkg
        ];
      };
      home.packages = [
        treesitterPkg
      ];
    };
}
