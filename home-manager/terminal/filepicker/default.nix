{ pkgs, lib, inputs, ... }: {
  imports = [ inputs.xdg-termfilepickers.homeManagerModules.default ];
  services.xdg-desktop-portal-termfilepickers = let
    termfilepickers =
      inputs.xdg-termfilepickers.packages.${pkgs.system}.default;
  in {
    enable = true;
    package = termfilepickers;
    config = {
      terminal_command = [ (lib.getExe pkgs.ghostty) "-e" ];
      open_file_script_path = ./open.nu;
      save_file_script_path = ./save.nu;
      save_files_script_path = ./save.nu;
    };
  };
}
