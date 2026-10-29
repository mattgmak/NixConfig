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

      # Home Manager builds the bat cache each activation. It still skips the
      # Stylix theme when the cache is absent or stale. Rebuild after it when
      # the theme file changes (bat issue #1726 needs an empty cwd).
      home.activation.batThemeCache = lib.hm.dag.entryAfter [ "batCache" ] ''
        if [ -f ${themePath} ]; then
          theme_hash=$(${pkgs.coreutils}/bin/sha256sum ${themePath} | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          if [ ! -f ${stamp} ] || [ "$(cat ${stamp})" != "$theme_hash" ]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${cacheDir}
            (
              export XDG_CACHE_HOME=${lib.escapeShellArg config.xdg.cacheHome}
              cd ${pkgs.emptyDirectory}
              $DRY_RUN_CMD ${config.programs.bat.package}/bin/bat cache --build > /dev/null 2>&1 || true
            )
            printf '%s' "$theme_hash" > ${stamp}
          fi
        fi
      '';
    };
}
