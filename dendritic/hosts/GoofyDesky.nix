{ inputs, self, ... }: {
  flake.nixosConfigurations.GoofyDesky = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = rec {
      system = "x86_64-linux";
      inherit inputs;
      inherit (self.constants) username;
      inherit (self.legacyPackages.${system})
        pkgs-stable pkgs-for-cursor pkgs-for-osu;
      hostname = self.constants.desktopName;
    };
    modules = [
      self.nixosModules.common
      self.nixosModules.GoofyDesky
      self.nixosModules.GoofyDeskyHardware
    ];
  };
  flake.nixosModules.GoofyDesky = { pkgs, pkgs-for-osu, pkgs-stable, ... }:
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
      imports = [ inputs.nixpkgs-xr.nixosModules.nixpkgs-xr ];

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
        autoStart = true;
      };

      programs.appimage = {
        enable = true;
        binfmt = true;
      };

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

    };

  # Do not modify this module!  It was generated by ‘nixos-generate-config’
  # and may be overwritten by future invocations.  Please make changes
  # to /etc/nixos/configuration.nix instead.
  flake.nixosModules.GoofyDeskyHardware = { config, lib, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

    boot.initrd.availableKernelModules =
      [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/b75e7142-2009-46cb-84f6-99cfb2b14191";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/867A-3EC6";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    swapDevices = [ ];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault true;
    # networking.interfaces.enp5s0.useDHCP = lib.mkDefault true;
    # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

}
