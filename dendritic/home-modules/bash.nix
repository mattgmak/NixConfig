{
  flake.homeModules.bash = {
    programs.bash = {
      enable = true;
      enableCompletion = true;
    };
    # Cursor (and similar) agents run bash; HM only injects this when bash is enabled.
    programs.direnv.enableBashIntegration = true;
  };
}
