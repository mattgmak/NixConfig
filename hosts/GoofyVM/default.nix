{ pkgs, ... }: {
  imports = [ ../common.nix ./hardware-configuration.nix ];
  virtualisation.virtualbox.guest.enable = true;
  system.copySystemConfiguration = true;
  services.openssh.enable = true;

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
