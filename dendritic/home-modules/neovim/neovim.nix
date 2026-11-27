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
      firenvimLockFile = "${neovimRoot}/config/firenvim-lock.json";
      firenvimRestoreStamp = "${config.home.homeDirectory}/.local/state/nvim/firenvim-lazy-restore.lock.sha256";
      # The wrapper, not the unwrapped binary: tree-sitter compiles parsers
      # with `cc`, which only the extraPackages wrapper puts on PATH.
      nvim = config.programs.neovim.finalPackage;
      # Firefox reads the manifest from ~/.mozilla/native-messaging-hosts; Zen
      # shares that path, so the launcher lives here instead of in the browser module.
      firenvimLauncher = pkgs.writeShellScript "firenvim" ''
        unset NVIM_LISTEN_ADDRESS
        cd "$HOME"
        exec ${nvim}/bin/nvim --headless --cmd "let g:firenvim_i=[]|let g:firenvim_o=[]|let g:Firenvim_oi={i,d,e->add(g:firenvim_i,d)}|let g:Firenvim_oo={t->[chansend(2,t)]+add(g:firenvim_o,t)}|let g:firenvim_c=stdioopen({'on_stdin':{i,d,e->g:Firenvim_oi(i,d,e)},'on_print':{t->g:Firenvim_oo(t)}})" --cmd "let g:started_by_firenvim = v:true" -c "try|call firenvim#run()|catch|call writefile([v:exception, v:throwpoint], '/tmp/firenvim.err')|qall!|endtry"
      '';
      # Stylix is absent on the minimal installer ISO; the lua side falls back.
      hasStylix = config.lib ? stylix;
      c = if hasStylix then config.lib.stylix.colors.withHashtag else { };
      # The flake nixpkgs carries the fixed go_1_27 = 1.27.3. Droid builds from a
      # multiverse anchor whose go_1_27 is 1.27rc2, so there keep plain `go`.
      goTooling =
        let
          go127 = pkgs.go_1_27 or null;
        in
        if go127 != null && lib.versionAtLeast go127.version "1.27.3" then go127 else pkgs.go;
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
      home.file = {
        ".config/nvim/after".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/after";
        ".config/nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lua";
        ".config/nvim/lazy-lock.json".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/lazy-lock.json";
        ".config/nvim/firenvim-lock.json".source =
          config.lib.file.mkOutOfStoreSymlink "${neovimRoot}/config/firenvim-lock.json";
      } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        ".mozilla/native-messaging-hosts/firenvim.json".source = pkgs.writeText "firenvim-manifest" (builtins.toJSON {
          name = "firenvim";
          description = "Turn your browser into a Neovim GUI.";
          path = "${firenvimLauncher}";
          type = "stdio";
          allowed_extensions = [ "firenvim@lacamb.re" ];
        });
      };
      programs.neovim = {
        enable = true;
        withPython3 = true;
        withNodeJs = true;
        withRuby = true;
        initLua =
          lib.optionalString hasStylix ''
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
          ''
          + ''
            ${pkgs.lib.optionalString (hostname == "Goofeus") "vim.g.disable_ui2 = true"}
            if vim.g.started_by_firenvim then
              require('firenvim_setup')
            else
              require('lazy_setup')
              require('config')
            end
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
          goTooling
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
        if [ -f ${lib.escapeShellArg lockFile} ]; then
          mkdir -p "$(dirname ${lib.escapeShellArg restoreStamp})"
          lock_hash=$(${pkgs.coreutils}/bin/sha256sum ${lib.escapeShellArg lockFile} | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          if [ ! -f ${lib.escapeShellArg restoreStamp} ] || [ "$(cat ${lib.escapeShellArg restoreStamp})" != "$lock_hash" ]; then
            export PATH="${restorePath}:$PATH"
            ${nvim}/bin/nvim --headless "+Lazy! restore" +qa
            printf '%s' "$lock_hash" > ${lib.escapeShellArg restoreStamp}
          fi
        fi
      '';
      # Pre-install the firenvim lazy set so the browser launch never prints
      # lazy's install progress to stdout, which breaks the native protocol.
      home.activation.restoreFirenvimPlugins = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
        inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -f ${lib.escapeShellArg firenvimLockFile} ]; then
            mkdir -p "$(dirname ${lib.escapeShellArg firenvimRestoreStamp})"
            lock_hash=$(${pkgs.coreutils}/bin/sha256sum ${lib.escapeShellArg firenvimLockFile} | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            if [ ! -f ${lib.escapeShellArg firenvimRestoreStamp} ] || [ "$(cat ${lib.escapeShellArg firenvimRestoreStamp})" != "$lock_hash" ]; then
              export PATH="${restorePath}:$PATH"
              ${nvim}/bin/nvim --headless --cmd "let g:started_by_firenvim = v:true" "+Lazy! restore" +qa >/dev/null
              printf '%s' "$lock_hash" > ${lib.escapeShellArg firenvimRestoreStamp}
            fi
          fi
        ''
      );
    };
}
