{ ... }: {
  home.file = {
    ".config/nushell/config.nu".source = ./config.nu;
    ".config/nushell/env.nu".source = ./env.nu;
    ".config/nushell/scripts/conda.nu".source = ./scripts/conda.nu;
  };
}
