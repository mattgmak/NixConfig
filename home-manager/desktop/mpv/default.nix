{ pkgs, ... }: {
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
  };
}
