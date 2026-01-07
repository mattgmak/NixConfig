{ pkgs, pkgs-for-osu, pkgs-stable, inputs, ... }:
let
  # orca-slicer-overlay = final: prev: {
  #   orca-slicer = prev.orca-slicer.overrideAttrs (old: {
  #     postInstall = (old.postInstall or "") + ''
  #       mv $out/bin/orca-slicer $out/bin/.orca-slicer-wrapped
  #       echo "env __GLX_VENDOR_LIBRARY_NAME=mesa __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink WEBKIT_DISABLE_DMABUF_RENDERER=1 $out/bin/.orca-slicer-wrapped" > $out/bin/orca-slicer
  #       chmod +x $out/bin/orca-slicer
  #     '';
  #   });
  # };
  orcaSlicerDesktopItem = pkgs.makeDesktopItem {
    name = "orca-slicer-dri";
    desktopName = "OrcaSlicer (DRI)";
    genericName = "3D Printing Software";
    icon = "OrcaSlicer";
    # exec = "env GBM_BACKEND=dri ${pkgs.orca-slicer}/bin/orca-slicer %U";
    exec =
      "env __GLX_VENDOR_LIBRARY_NAME=mesa __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink WEBKIT_DISABLE_DMABUF_RENDERER=1 ${pkgs.orca-slicer}/bin/orca-slicer %U";
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
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
    # autoStart = true;
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # nixpkgs.overlays = [ orca-slicer-overlay ];

  environment.systemPackages = with pkgs; [
    bitwarden-desktop
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
    qbittorrent
    gparted
    appflowy
    qmk
    qmk-udev-rules
    qmk_hid
    via
    vial
    kbd
    pkgs-stable.vesktop
    prismlauncher
    hyperhdr
    orcaSlicerDesktopItem
    orca-slicer
    google-chrome
    pkgs-for-osu.osu-lazer-bin
    onedrivegui
    bs-manager
    sidequest
    android-tools
    kdePackages.wacomtablet
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
      (pkgs.callPackage ../../modules/final-mouse-udev-rules.nix { })
    ]; # packages
  }; # udev

  services.xserver.wacom.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva-vdpau-driver
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
      modesetting.enable = true;
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

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "deepseek-r1:8b" ];
  };

  system.stateVersion = "24.11";

}
