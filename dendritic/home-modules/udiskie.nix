{
  flake.homeModules.udiskie =
    { pkgs, ... }:
    {
      services.udiskie = {
        enable = true;
        automount = false;
        settings = {
          program_options = {
            file_manager = "${pkgs.ghostty}/bin/ghostty";
          };
        };
      };
      home.packages = with pkgs; [
        udiskie
      ];
    };
}
