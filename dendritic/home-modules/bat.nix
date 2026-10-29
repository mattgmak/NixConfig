{
  flake.homeModules.bat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      themePath = "${config.xdg.configHome}/bat/themes/base16-stylix.tmTheme";
      cacheDir = "${config.xdg.cacheHome}/bat";
      stamp = "${cacheDir}/.stylix-theme-hash";
    in
    {
      programs.bat = {
        enable = true;
      };

      # bat 0.26 builds no cache on first run, so it never reads the Stylix
      # theme. Rebuild the cache when the theme file changes.
      home.activation.batCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f ${themePath} ]; then
          theme_hash=$(${pkgs.coreutils}/bin/sha256sum ${themePath} | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          if [ ! -f ${stamp} ] || [ "$(cat ${stamp})" != "$theme_hash" ]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${cacheDir}
            $DRY_RUN_CMD ${config.programs.bat.package}/bin/bat cache --build > /dev/null 2>&1 || true
            printf '%s' "$theme_hash" > ${stamp}
          fi
        fi
      '';
    };
}
