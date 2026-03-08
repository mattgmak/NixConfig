{ inputs, ... }: {
  flake.homeModules.neovim =
    { pkgs, ... }:
    let treesitterPkg = inputs.tree-sitter.packages.${pkgs.stdenv.hostPlatform.system}.default; in
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
          treesitterPkg
        ];
      };
      home.packages = with pkgs; [
        treesitterPkg
      ];
    };
}
