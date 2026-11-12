{ self, ... }:
{
  flake.homeModules.yazi =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        # Overlay maps pkgs.yazi to the prebuilt packages.yaziBin.
        package = pkgs.yazi;
        enableNushellIntegration = false;
        shellWrapperName = "y";
        initLua = ./init.lua;
        plugins = with pkgs.yaziPlugins; {
          inherit git yatline yatline-created-time;

          system-clipboard = pkgs.callPackage self.yaziPluginSystemClipboard { };
          yatline-modified-time = pkgs.callPackage self.yaziPluginYatlineModifiedTime { };
          yatline-page-counter = pkgs.callPackage self.yaziPluginYatlinePageCounter { };
          yatline-selected-size = pkgs.callPackage self.yaziPluginYatlineSelectedSize { };
          yatline-symlink = pkgs.callPackage self.yaziPluginYatlineSymlink { };
          yatline-tab-path = pkgs.callPackage self.yaziPluginYatlineTabPath { };
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
        _7zz-rar # RAR extraction, the prebuilt yazi is unwrapped
        clipboard-jh # `cb`, the binary system-clipboard.yazi spawns
        djvulibre # `djvused`, used by yatline-page-counter for DjVu files
        unzip # yatline-page-counter reads EPUB and Office documents as archives
        file # `file` previewer/spotter, no wrapper means PATH lookup
        imagemagick # `magick` previewer
        poppler-utils # `pdftoppm` PDF previewer
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
              name = "fg-rga";
              pkg = pkgs.callPackage self.yaziPluginFgRga { };
            }
            {
              name = "compress";
              pkg = pkgs.callPackage self.yaziPluginCompress { };
            }
            {
              name = "searchjump";
              pkg = pkgs.callPackage self.yaziPluginSearchjump { };
            }
            {
              name = "folder-rules";
              pkg = pkgs.callPackage self.yaziPluginFolderRules { };
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
        };
    };
}
