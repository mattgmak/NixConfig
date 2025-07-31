{ pkgs, ... }: {
  stylix = {
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    targets.gnome-text-editor.enable = false;
  };
}
