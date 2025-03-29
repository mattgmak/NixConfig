{ ... }: {
  home.file = {
    ".config/nushell" = {
      source = ./config;
      recursive = true;
    };
  };
}
