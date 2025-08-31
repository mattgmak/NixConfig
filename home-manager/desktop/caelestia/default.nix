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

  home.file."Pictures/Wallpapers/wallpaper.jpg" = {
    source = ../../../modules/style/beautiful-mountains-landscape.jpg;
  };

  # home.packages = [ inputs.caelestia-shell.packages.${pkgs.system}.default ];
}
