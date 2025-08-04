{ pkgs, ... }:
let
  orcaSlicerDesktopItem = pkgs.makeDesktopItem {
    name = "orca-slicer-dri";
    desktopName = "OrcaSlicer (DRI)";
    genericName = "3D Printing Software";
    icon = "OrcaSlicer";
    exec = "env GBM_BACKEND=dri ${pkgs.orca-slicer}/bin/orca-slicer %U";
    terminal = false;
    type = "Application";
    mimeTypes = [
      "model/stl"
      "model/3mf"
      "application/vnd.ms-3mfdocument"
      "application/prs.wavefront-obj"
      "application/x-amf"
      "x-scheme-handler/orcaslicer"
    ];
    categories = [ "Graphics" "3DGraphics" "Engineering" ];
    keywords = [
      "3D"
      "Printing"
      "Slicer"
      "slice"
      "3D"
      "printer"
      "convert"
      "gcode"
      "stl"
      "obj"
      "amf"
      "SLA"
    ];
    startupNotify = false;
    startupWMClass = "orca-slicer";
  };

  mimeappsListContent = ''
    [Default Applications]
    model/stl=orca-slicer-dri.desktop;
    model/3mf=orca-slicer-dri.desktop;
    application/vnd.ms-3mfdocument=orca-slicer-dri.desktop;
    application/prs.wavefront-obj=orca-slicer-dri.desktop;
    application/x-amf=orca-slicer-dri.desktop;

    [Added Associations]
    model/stl=orca-slicer-dri.desktop;
    model/3mf=orca-slicer-dri.desktop;
    application/vnd.ms-3mfdocument=orca-slicer-dri.desktop;
    application/prs.wavefront-obj=orca-slicer-dri.desktop;
    application/x-amf=orca-slicer-dri.desktop;
  '';

  orcaSlicerMimeappsList =
    pkgs.writeText "orca-slicer-mimeapps.list" mimeappsListContent;
in {
  # Bootloader
  imports = [ ./hardware-configuration.nix ../common.nix ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  environment.systemPackages = with pkgs; [
    bitwarden-desktop
    libsForQt5.kdeconnect-kde
    libnotify
    obsidian
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
    vesktop
    prismlauncher
    hyperhdr
    orcaSlicerDesktopItem
  ];

  environment.etc."xdg/mimeapps.list".source = orcaSlicerMimeappsList;
  environment.etc."xdg/mimeapps.list".mode = "0644";

  boot = {
    loader = {
      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
        useOSProber = true;
      };
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  fileSystems."/mnt/windows/c" = {
    # device = "/dev/nvme1n1p4";
    device = "/dev/disk/by-uuid/FC880B87880B401E";
    fsType = "ntfs";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/mnt/windows/d" = {
    # device = "/dev/sdb2";
    device = "/dev/disk/by-uuid/F6025F5D025F21C3";
    fsType = "ntfs";
    options = [ "defaults" "nofail" ];
  };

  systemd.services.hyperhdr = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "goofy";
      Group = "dialout";
      ExecStart = "${pkgs.hyperhdr}/bin/hyperhdr";
    };
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

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau
        libvdpau-va-gl
        vdpauinfo
        libva
        libva-utils
      ];
    };
    nvidia = {
      open = true;
      powerManagement.enable = true;
    };
  };
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

  system.stateVersion = "24.11";

}
