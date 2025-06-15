{ username, ... }: {
  programs.nushell = {
    enable = true;
    configFile.text = builtins.readFile ./config/config.nu;
    envFile.text = builtins.readFile ./config/env.nu;
    environmentVariables = { NH_OS_FLAKE = "/home/${username}/NixConfig"; };
  };

  home.file = {
    ".nushell-extra" = {
      source = ./config/scripts;
      recursive = true;
    };
  };
}
