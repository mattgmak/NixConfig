{
  flake.homeModules.nushell =
    {
      username,
      pkgs,
      lib,
      ...
    }:
    let
      linuxHome = if username == "root" then "/root" else "/home/${username}";
    in
    {
      programs.nushell = {
        enable = true;
        configFile.source = ./config/config.nu;
        envFile.source = ./config/env.nu;
        # To order the extra config after zoxide with default (1000)
        extraConfig = lib.mkOrder 1100 (builtins.readFile ./config/extra.nu);
        environmentVariables = {
          NH_OS_FLAKE = lib.mkIf pkgs.stdenv.isLinux "${linuxHome}/NixConfig";
          NH_DARWIN_FLAKE = lib.mkIf pkgs.stdenv.isDarwin "/Users/${username}/NixConfig#darwinConfigurations.MacMini";
          DEVELOPER_DIR = lib.mkIf pkgs.stdenv.isDarwin "/Applications/Xcode.app/Contents/Developer";
        };
      };
    };
}
