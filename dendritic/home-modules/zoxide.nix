{
  flake.homeModules.zoxide =
    { lib, config, ... }:
    {
      programs.zoxide = {
        enable = true;
        # HM default init registers PWD hook on every `nu -c` (pi tool shells).
        enableNushellIntegration = false;
      };

      programs.nushell.extraConfig = lib.mkIf config.programs.nushell.enable (
        lib.mkOrder 1000 (builtins.readFile ./nushell/config/zoxide.nu)
      );
    };
}
