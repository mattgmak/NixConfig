{ inputs, ... }:
{
  flake.homeModules.worktrunk = {
    imports = [ inputs.worktrunk.homeModules.default ];
    programs.worktrunk = {
      enable = true;
      enableNushellIntegration = true;
    };
    home.file.".config/worktrunk/config.toml".source = ./config.toml;
  };
}
