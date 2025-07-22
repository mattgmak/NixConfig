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
  imports =
    [ ./hardware-configuration.nix ../common.nix cursorUIStyleWithPkgs ];

  # Configure cursor UI style with the requested settings
  programs.cursor-ui-style = {
    enable = true;
    autoApply = true; # Re-enable autoApply to use the fixed module overlay
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
    customFiles = [ ../../home-manager/desktop/vscode-custom/vscode.css ];
  };

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
    inputs.zen-browser.packages."${system}".default
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
    # Use code-cursor from pkgs-for-cursor if available, otherwise from pkgs
    code-cursor
    # (if pkgs-for-cursor ? code-cursor then
    #   pkgs-for-cursor.code-cursor
    # else
    #   pkgs.code-cursor)
    # orca-slicer
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
    device = "/dev/nvme1n1p4";
    fsType = "ntfs";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/mnt/windows/d" = {
    device = "/dev/sdb2";
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
  hardware.nvidia.open = true;
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
