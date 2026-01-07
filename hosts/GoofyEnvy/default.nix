{ pkgs, username, pkgs-stable, inputs, ... }:
let
in {
  # Bootloader
  imports = [
    ../../modules/input-remapper.nix
    ./hardware-configuration.nix
    ../common.nix
    inputs.xremap-flake.nixosModules.default
  ];

  environment.systemPackages = with pkgs; [
    bitwarden-desktop
    wezterm
    libnotify
    obsidian
    pkgs-stable.vesktop
    protonvpn-gui
    wl-clipboard
    clipse
    pulseaudio-ctl
    brightnessctl
    playerctl
    bluetui
    networkmanagerapplet
    overskride
    wev
    evtest
    btop
    chromium
    xorg.xeyes
    kdePackages.okular
    mpv
    qbittorrent
    gparted
    appflowy
    qmk
    qmk-udev-rules
    qmk_hid
    via
    vial
    kbd
    zoom-us
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  services.xremap = {
    userName = username;
    withHypr = true;
    # Map CapsLock to Escape
    yamlConfig = ''
      modmap:
        - name: "CapsLock"
          remap:
            CapsLock: esc
      keymap:
        - name: "Super-u"
          remap:
            Super-u: NumLock
    '';
  };

  services.udev = {
    packages = with pkgs; [
      qmk
      qmk-udev-rules # the only relevant
      qmk_hid
      via
      vial
    ]; # packages
  }; # udev

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
      splix
      cups-kyocera
      foomatic-db
      foomatic-db-engine
      foomatic-db-ppds
      cups-filters
    ];
    # Enable browsing of printers that are shared on the network
    browsing = true;
    allowFrom = [ "all" ];
    listenAddresses = [ "*:631" ];
    defaultShared = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = { General = { Enable = "Source,Sink,Media,Socket"; }; };
  };
  services.blueman.enable = true;

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024;
  }];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  system.stateVersion = "24.11";

}
