{ username, pkgs, ... }: {
  programs.nushell = {
    enable = true;
    configFile.text = builtins.readFile ./config/config.nu;
    envFile.text = builtins.readFile ./config/env.nu;
    environmentVariables = {
      NH_OS_FLAKE =
        pkgs.lib.mkIf pkgs.stdenv.isLinux "/home/${username}/NixConfig";
      NH_DARWIN_FLAKE =
        pkgs.lib.mkIf pkgs.stdenv.isDarwin "/Users/${username}/NixConfig";
    };
  };

  home.file = {
    ".nushell-extra" = {
      source = ./config/scripts;
      recursive = true;
    };
  };
}
