{ ... }: {
  # Bootloader
  imports = [ ./hardware-configuration.nix ../common.nix ];
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

}
