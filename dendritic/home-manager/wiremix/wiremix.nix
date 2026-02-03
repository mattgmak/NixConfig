{
  flake.homeModules.wiremix = {
    home.file.".config/wiremix/wiremix.toml" = {
      source = ./wiremix.toml;
    };
  };
}
