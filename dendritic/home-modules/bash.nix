{
  flake.homeModules.bash = {
    programs.bash = {
      enable = true;
      enableCompletion = true;
    };
    # Agents run bash; HM only injects this when bash is enabled.
    programs.direnv.enableBashIntegration = true;
  };
}
