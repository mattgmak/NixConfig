{
  flake.homeModules.bluetui = {
    home.file = {
      ".config/bluetui/config.toml".source = ./config.toml;
    };
  };
}
