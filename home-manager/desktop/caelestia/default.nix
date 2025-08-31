{ inputs, pkgs, config, ... }: {
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    systemd.enable = false;
    settings = { };
    cli = {
      enable = true;
      settings = { theme.enableGtk = false; };
    };
  };

  # home.packages = [ inputs.caelestia-shell.packages.${pkgs.system}.default ];
}
