{ pkgs, username, inputs, pkgs-for-cursor, lib, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Create a module that passes pkgs-for-cursor to cursor-ui-style
  cursorUIStyleWithPkgs = { config, lib, pkgs, ... }: {
    imports = [
      (import ../../modules/cursor-ui-style {
        inherit config lib pkgs;
        pkgs-for-cursor = pkgs-for-cursor;
      })
    ];
  };
in {
  # Bootloader
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    inputs.xremap-flake.nixosModules.default
    cursorUIStyleWithPkgs
  ];

  # Configure cursor UI style with the requested settings
  programs.cursor-ui-style = {
    enable = true;
    autoApply = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
  };

  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages."${system}".default
    bitwarden-desktop
    wezterm
    libsForQt5.kdeconnect-kde
    libnotify
    obsidian
    webcord
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
    okular
    mpv
    yt-dlp
    qbittorrent
    gparted
    appflowy
    qmk
    qmk-udev-rules
    qmk_hid
    via
    vial
    kbd
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

  # Add onedrive service
  services.onedrive = {
    enable = true;
    package = pkgs.onedrive;
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

  services.fprintd = { enable = true; };

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024;
  }];

  system.stateVersion = "24.11";

}
