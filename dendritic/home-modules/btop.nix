{
  flake.homeModules.btop = {
    programs.btop = {
      enable = true;
      settings = {
        update_ms = 1000;
      };
    };
  };
}
