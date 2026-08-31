{
  flake.homeModules.devenv = {
    programs.devenv = {
      enable = true;
      enableNushellIntegration = false;
    };
  };
}
