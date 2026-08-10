{
  flake.homeModules.delta = {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        tabs = 4;
      };
    };
  };
}
