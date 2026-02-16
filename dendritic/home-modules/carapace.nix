{
  flake.homeModules.carapace = {
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
