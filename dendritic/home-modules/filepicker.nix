{ inputs, ... }: {
  flake.homeModules.filepicker = { pkgs, lib, ... }: {
    imports = [ inputs.xdg-termfilepickers.homeManagerModules.default ];
    services.xdg-desktop-portal-termfilepickers = let
      termfilepickers =
        inputs.xdg-termfilepickers.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in {
      enable = true;
      package = termfilepickers;
      config = { terminal_command = [ (lib.getExe pkgs.ghostty) "-e" ]; };
    };
  };
}
