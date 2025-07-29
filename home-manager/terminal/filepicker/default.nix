{ pkgs, lib, inputs, ... }: {
  imports = [ inputs.xdg-termfilepickers.homeManagerModules.default ];
  services.xdg-desktop-portal-termfilepickers = let
    termfilepickers =
      inputs.xdg-termfilepickers.packages.${pkgs.system}.default;
  in {
    enable = true;
    package = termfilepickers;
    config = {
      terminal_command = lib.getExe pkgs.ghostty;
      open_file_script_path = ./yazi-open-file.nu;
      save_file_script_path = ./yazi-save-file.nu;
      save_files_script_path = ./yazi-save-file.nu;
    };
  };
}
