{
  flake.homeModules.cs2 = {
    home.file = {
      ".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg" = {
        source = ./cfg;
        recursive = true;
      };
    };
  };
}
