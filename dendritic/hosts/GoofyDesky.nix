{
  inputs,
  self,
  withSystem,
  ...
}:
{
  flake = {
    nixosConfigurations.GoofyDesky = withSystem "x86_64-linux" (
      { config, inputs', ... }:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs inputs';
          inherit (config) packages;
          inherit (self.constants) username;
          inherit (config.legacyPackages) pkgs-stable pkgs-for-cursor pkgs-for-vr;
          hostname = self.constants.desktopName;
        };
        modules = with self.nixosModules; [
          common
          inputs.agenix.nixosModules.default
          copyparty-client
          GoofyDesky
          GoofyDeskyHardware
          orca-slicer
          steam
          vr
          tailscale
        ];
      }
    );

    homeConfigurations.GoofyDesky = {
      imports = with self.homeModules; [
        nixos-home
        atuin
        zoxide
        zen-browser
        cs2
        nushell
        wezterm
        neovim
        starship
        yazi
        git
        delta
        gh
        direnv
        lazygit
        mangohud
        ghostty
        cursor
        carapace
        bluetui
        hyprland
        # waybar
        wlogout
        fcitx5
        mpv
        kdeconnect
        filepicker
        wiremix
        caelestia
        xdg
        udiskie
        zellij
        tmux
        whisper-dictation
        worktrunk
        gh-dash
        btop
        bat
        nix-index-database
        tailscale-systray
        opencode
        bash
      ];
    };

    nixosModules.GoofyDesky =
      {
        config,
        pkgs,
        pkgs-stable,
        inputs,
        username,
        packages,
        ...
      }:
      {
        home-manager.users.${username} = self.homeConfigurations.GoofyDesky;
        programs.appimage = {
          enable = true;
          binfmt = true;
        };

        # copyparty on Goofeus: on-demand WebDAV via copyparty-mount (see programs.copyparty-client).
        age.secrets.copyparty-goofy-pass = {
          file = ../../secrets/copyparty-goofy-pass.age;
          owner = username;
          mode = "0400";
        };

        programs.copyparty-client = {
          enable = true;
          url = "https://goofeus.dab-octatonic.ts.net/";
          mountPoint = "/mnt/copyparty";
          passwordFile = config.age.secrets.copyparty-goofy-pass.path;
          webdavUser = username;
          localUser = username;
        };

        environment.systemPackages = with pkgs; [
          immich-go
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
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
          chromium
          xorg.xeyes
          kdePackages.okular
          qbittorrent
          gparted
          tparted
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
          google-chrome
          onedrivegui
          android-tools
          kdePackages.wacomtablet
          packages.osu-lazer-bin
        ];

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
          options = [
            "defaults"
            "nofail"
          ];
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
            self.packages.${pkgs.stdenv.hostPlatform.system}.finalMouseUdevRules
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
          settings = {
            General = {
              Enable = "Source,Sink,Media,Socket";
            };
          };
        };
        services.blueman.enable = true;

        swapDevices = [
          {
            device = "/swapfile";
            size = 16 * 1024;
          }
        ];

        services.ollama = {
          enable = true;
          package = pkgs.ollama-cuda;
          loadModels = [ "deepseek-r1:8b" ];
        };

        users.users.${username}.openssh.authorizedKeys.keys = [
          self.sshKeys.Droid
        ];
        services.openssh.enable = true;
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

        system.stateVersion = "24.11";

      };

    # Do not modify this module!  It was generated by ‘nixos-generate-config’
    # and may be overwritten by future invocations.  Please make changes
    # to /etc/nixos/configuration.nix instead.
    nixosModules.GoofyDeskyHardware =
      {
        config,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

        boot.initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "nvme"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
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
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
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
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

  };
}
