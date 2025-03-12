{ pkgs, config, ... }: {
  imports = [ ../common.nix ./hardware-configuration.nix ];
  virtualisation.virtualbox.guest.enable = true;
  services.openssh.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.systemPackages = with pkgs; [
    firefox
    curl
    wget
    git
    neovim
    parted
  ];
  system.stateVersion = "24.11";
}
