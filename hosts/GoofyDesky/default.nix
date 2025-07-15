{ pkgs, inputs, pkgs-for-cursor, ... }:
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
    enable = false;
    autoApply = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
    customFiles = [ ../../home-manager/desktop/vscode-custom/vscode.css ];
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
    kdePackages.okular
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
    # Use code-cursor from pkgs-for-cursor if available, otherwise from pkgs
    (if pkgs-for-cursor ? code-cursor then
      pkgs-for-cursor.code-cursor
    else
      pkgs.code-cursor)
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
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
