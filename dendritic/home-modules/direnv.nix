{
  flake.homeModules.direnv = {
    programs.direnv = {
      enable = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
      # Whole drpom_tcm tree trusted, so new subproject .envrc needs no manual allow.
      config.whitelist.prefix = [
        "/home/goofy/code/drpom_tcm"
        "/Volumes/Kingston480GB/code/tcm"
      ];
    };
  };
}
