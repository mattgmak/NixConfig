{
  flake.homeModules.hyprpaper = {
    services.hyprpaper =
      let
        wallpaper = "~/Pictures/wallpapers/beautiful-mountains-landscape.jpg";
      in
      {
        enable = true;
        settings = {
          preload = [ wallpaper ];
          wallpaper = [ ",${wallpaper}" ];
        };
      };
  };
}
