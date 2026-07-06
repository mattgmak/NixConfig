{ inputs, ... }:
{
  flake.homeModules.neovim =
    { config, pkgs, hostname, ... }:
    let
      treesitterPkg = inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default;
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      neovimRoot = "${repoRoot}/home-modules/neovim";
    in
    {
      home.file = {
        ".config/nvim/after".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/after";
        ".config/nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua";
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        withRuby = true;
        initLua = ''
          ${pkgs.lib.optionalString (hostname == "Goofeus") "vim.g.disable_ui2 = true"}
          require('lazy_setup')
          require('config')
        '';
        extraLuaPackages = ps: [ ps.magick ];
        extraPackages = with pkgs; [
          lua-language-server
          nixd
          gcc
          gnumake
          go
          ripgrep
          fd
          treesitterPkg
          imagemagick
          ueberzugpp
          config.programs.yazi.package
        ];
      };
      home.packages = [
        treesitterPkg
      ];
    };
}
