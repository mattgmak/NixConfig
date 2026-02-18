{ self, inputs, ... }:
{
  flake.homeModules.yazi =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          _7zz = pkgs._7zz-rar; # Support for RAR extraction
        };
        enableNushellIntegration = true;
        initLua = ./init.lua;
        plugins = with pkgs.yaziPlugins; {
          inherit git;
        };
        theme = {
          indicator = {
            padding = {
              open = "█";
              close = "█";
            };
          };
        };
      };
      # TODO: use nixpkgs plugins

      home.packages = with pkgs; [
        glow
        bat
        fzf
        ripgrep
        fd
        ripgrep-all
        eza
        hexyl
      ];

      home.file =
        let
          baseConfigPath = ".config/yazi";
          basePluginPath = "${baseConfigPath}/plugins";
          baseOutputPath = "share/yazi/plugins";
          plugins = [
            {
              name = "piper";
              pkg = pkgs.callPackage self.yaziPluginPiper { };
            }
            {
              name = "relative-motions";
              pkg = pkgs.callPackage self.yaziPluginRelativeMotions { };
            }
            {
              name = "max-preview";
              pkg = pkgs.callPackage self.yaziPluginMaxPreview { };
            }
            {
              name = "fg";
              pkg = pkgs.callPackage self.yaziPluginFg { };
            }
            {
              name = "compress";
              pkg = pkgs.callPackage self.yaziPluginCompress { };
            }
            {
              name = "searchjump";
              pkg = pkgs.callPackage self.yaziPluginSearchjump { };
            }
          ];
        in
        (builtins.listToAttrs (
          map (plugin: {
            name = "${basePluginPath}/${plugin.name}.yazi";
            value = {
              source = "${plugin.pkg}/${baseOutputPath}/${plugin.name}";
            };
          }) plugins
        ))
        // {
          "${baseConfigPath}/yazi.toml" = {
            source = ./yazi.toml;
          };
          "${baseConfigPath}/keymap.toml" = {
            source = ./keymap.toml;
          };
          # "${baseConfigPath}/theme.toml" = { source = ./theme.toml; };
          "${baseConfigPath}/scripts/cursor-open.nu".source = ./scripts/cursor-open.nu;
        };
    };
}
