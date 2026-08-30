{ inputs, ... }:
{
  flake.homeModules.neovim =
    {
      config,
      pkgs,
      hostname,
      lib,
      ...
    }:
    let
      treesitterPkg = pkgs.tree-sitter;
      repoRoot = "${config.home.homeDirectory}/NixConfig/dendritic";
      neovimRoot = "${repoRoot}/home-modules/neovim";
      lockFile = "${neovimRoot}/config/lazy-lock.json";
      restoreStamp = "${config.home.homeDirectory}/.local/state/nvim/lazy-restore.lock.sha256";
      nvim = config.programs.neovim.package;
      c = config.lib.stylix.colors.withHashtag;
      restorePath = lib.makeBinPath (
        with pkgs;
        [
          coreutils
          git
          gnumake
          gcc
        ]
      );
    in
    {
      stylix.targets.neovim.enable = true;

      home.file = {
        ".config/nvim/after".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/after";
        ".config/nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua";
        ".config/nvim/lazy-lock.json".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lazy-lock.json";
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        withRuby = true;
        initLua = ''
          vim.g.stylix_palette = {
            base00 = "${c.base00}",
            base01 = "${c.base01}",
            base02 = "${c.base02}",
            base03 = "${c.base03}",
            base04 = "${c.base04}",
            base05 = "${c.base05}",
            base06 = "${c.base06}",
            base07 = "${c.base07}",
            base08 = "${c.base08}",
            base09 = "${c.base09}",
            base0A = "${c.base0A}",
            base0B = "${c.base0B}",
            base0C = "${c.base0C}",
            base0D = "${c.base0D}",
            base0E = "${c.base0E}",
            base0F = "${c.base0F}",
          }
          ${pkgs.lib.optionalString (hostname == "Goofeus") "vim.g.disable_ui2 = true"}
          require('lazy_setup')
          require('config')
        '';
        extraLuaPackages = ps: [ ps.magick ];
        extraPackages = with pkgs; [
          lua-language-server
          nixd
          bash-language-server
          shfmt
          shellcheck
          gcc
          gnumake
          go
          ripgrep
          fd
          treesitterPkg
          imagemagick
          # ueberzugpp
          config.programs.yazi.package
        ];
      };
      home.packages = [
        treesitterPkg
      ];

      home.activation.restoreLazyPlugins = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f ${lib.escapeShellArg lockFile} ]; then
          exit 0
        fi

        mkdir -p "$(dirname ${lib.escapeShellArg restoreStamp})"
        lock_hash=$(${pkgs.coreutils}/bin/sha256sum ${lib.escapeShellArg lockFile} | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        if [ -f ${lib.escapeShellArg restoreStamp} ] && [ "$(cat ${lib.escapeShellArg restoreStamp})" = "$lock_hash" ]; then
          exit 0
        fi

        export PATH="${restorePath}:$PATH"
        ${nvim}/bin/nvim --headless "+Lazy! restore" +qa
        printf '%s' "$lock_hash" > ${lib.escapeShellArg restoreStamp}
      '';
    };
}
