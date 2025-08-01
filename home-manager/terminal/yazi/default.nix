{ pkgs, ... }: {
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    initLua = ./init.lua;
  };

  home.packages = with pkgs; [ glow bat fzf ripgrep fd ripgrep-all ];

  home.file = let
    baseConfigPath = ".config/yazi";
    basePluginPath = "${baseConfigPath}/plugins";
    baseOutputPath = "share/yazi/plugins";
    plugins = [
      {
        name = "glow";
        pkg = pkgs.callPackage ./plugins/glow.nix { };
      }
      # {
      #   name = "starship";
      #   pkg = pkgs.callPackage ./plugins/starship.nix { };
      # }
      {
        name = "relative-motions";
        pkg = pkgs.callPackage ./plugins/relative-motions.nix { };
      }
      {
        name = "max-preview";
        pkg = pkgs.callPackage ./plugins/max-preview.nix { };
      }
      {
        name = "fg";
        pkg = pkgs.callPackage ./plugins/fg.nix { };
      }
      {
        name = "fr";
        pkg = pkgs.callPackage ./plugins/fr.nix { };
      }
      {
        name = "compress";
        pkg = pkgs.callPackage ./plugins/compress.nix { };
      }
      {
        name = "searchjump";
        pkg = pkgs.callPackage ./plugins/searchjump.nix { };
      }
    ];
  in (builtins.listToAttrs (map (plugin: {
    name = "${basePluginPath}/${plugin.name}.yazi";
    value = { source = "${plugin.pkg}/${baseOutputPath}/${plugin.name}"; };
  }) plugins)) // {
    "${baseConfigPath}/yazi.toml" = { source = ./yazi.toml; };
    "${baseConfigPath}/keymap.toml" = { source = ./keymap.toml; };
    # "${baseConfigPath}/theme.toml" = { source = ./theme.toml; };
  };
}
