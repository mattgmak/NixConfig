{
  inputs,
  self,
  withSystem,
  ...
}:
{
  flake = {
    nixosConfigurations.GoofyDesky = withSystem "x86_64-linux" (
      {
        self',
        config,
        inputs',
        ...
      }:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs inputs';
          inherit (config) packages common-overlays common-nixpkgs-config;
          inherit (self.constants) username;
          mv = self'.legacyPackages.mv;
          hostname = self.constants.desktopName;
        };
        modules = with self.nixosModules; [
          common
          inputs.agenix.nixosModules.default
          copyparty-client
          GoofyDesky
          GoofyDeskyHardware
          orca-slicer
          ardour
          gamemode
          cpuTuning
          gpuTuning
          steam
          vr
          tailscale
          ai
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
        pi-coding-agent
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
      whisperDictation = {
        packageName = "whisper-dictation-vulkan";
        inputDevice = "Svalboard lightly";
      };
    };

    nixosModules.GoofyDesky =
      {
        config,
        lib,
        pkgs,
        inputs,
        username,
        packages,
        common-overlays,
        common-nixpkgs-config,
        ...
      }:
      {
        age.secrets.nix-builder-key = {
          file = ../../secrets/nix-builder-goofydesky.age;
          mode = "0400";
        };

        nix.settings = {
          secret-key-files = [ config.age.secrets.nix-builder-key.path ];
          trusted-users = lib.mkAfter [
            "root"
            "goofy"
            "@wheel"
          ];
        };

        nixpkgs.overlays = common-overlays;
        nixpkgs.config = lib.mkMerge [
          common-nixpkgs-config
          {
            cudaSupport = false;
            packageOverrides =
              pkgs:
              let
                # CUDA llama-cpp: nixpkgs default is CPU-only. OpenBLAS + native CPU flags.
                goofyCudaLlamaCpp =
                  (pkgs.llama-cpp.override {
                    cudaSupport = true;
                    rocmSupport = false;
                    metalSupport = false;
                    blasSupport = true;
                  }).overrideAttrs
                    (oldAttrs: {
                      # b10450 — fixes Qwen3.8 DeltaNet CUDA garbage output (ggml-org#27164).
                      version = "10450";
                      src = pkgs.fetchFromGitHub {
                        owner = "ggml-org";
                        repo = "llama.cpp";
                        rev = "ece963f41b0b02d7a0d61436ae365762c073a4c8";
                        hash = "sha256-E7b9asZsVnPydxHsHliMK9qSxZ2KZG7kff445MCD3ZQ=";
                        leaveDotGit = true;
                        postFetch = ''
                          git -C "$out" rev-parse --short HEAD > $out/COMMIT
                          find "$out" -name .git -print0 | xargs -0 rm -rf
                        '';
                      };
                      npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
                      cmakeFlags =
                        (lib.filter (f: !(lib.hasInfix "LLAMA_BUILD_NUMBER" f)) (oldAttrs.cmakeFlags or [ ]))
                        ++ [
                          (lib.cmakeFeature "LLAMA_BUILD_NUMBER" "10450")
                          "-DGGML_NATIVE=ON"
                          "-DCMAKE_CUDA_ARCHITECTURES=86" # RTX 3070 Ti — sandbox has no GPU
                        ];
                      preConfigure = ''
                        export NIX_ENFORCE_NO_NATIVE=0
                        ${oldAttrs.preConfigure or ""}
                      '';
                    });
              in
              {
                llama-cpp = goofyCudaLlamaCpp;

                # llama-swap from GitHub releases
                llama-swap = pkgs.runCommand "llama-swap" { } ''
                  mkdir -p $out/bin
                  tar -xzf ${
                    pkgs.fetchurl {
                      url = "https://github.com/mostlygeek/llama-swap/releases/download/v211/llama-swap_211_linux_amd64.tar.gz";
                      hash = "sha256-/2KqcCz2axJlRvpjwOvKbQ1rzkp4H1ys+DTi583bRGU=";
                    }
                  } -C $out/bin
                  chmod +x $out/bin/llama-swap
                '';
              };
          }
        ];

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
          xeyes
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

        # NVIDIA gaming: max perf PowerMizer env + low-latency frame cap. VRR/G-Sync off.
        environment.sessionVariables = {
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __GL_VRR_ALLOWED = "0";
          __GL_SYNC_TO_VBLANK = "0";
          __GL_MaxFramesAllowed = "1";
        };

        hardware = {
          graphics = {
            enable = true;
            enable32Bit = true;
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

        systemd.user.services.nvidia-gaming-settings = {
          description = "NVIDIA max-performance PowerMizer";
          after = [
            "graphical-session-pre.target"
            "xdg-desktop-portal.service"
          ];
          wantedBy = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # --no-config avoids blocking on org.freedesktop.portal.Settings when
            # portal backends are still starting; partOf was removed because that
            # blocked graphical-session.target for the full dbus timeout (~25s).
            TimeoutStartSec = 5;
            ExecStart = "${config.hardware.nvidia.package.settings}/bin/nvidia-settings --no-config -a [gpu:0]/GPUPowerMizerMode=1";
          };
        };

        swapDevices = [
          {
            device = "/swapfile";
            size = 48 * 1024;
          }
        ];

        zramSwap = {
          enable = true;
          memoryPercent = 50; # 16 GiB zram on 32 GiB RAM
        };

        users.users.${username}.openssh.authorizedKeys.keys = [
          self.sshKeys.Droid
        ];
        services.openssh.enable = true;
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

        system.stateVersion = "24.11";

        services.cpuTuning = {
          enable = true;
          governor = "schedutil";
        };

        services.gpuTuning = {
          enable = true;
          lockGraphicsMhz = 1875;
        };

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
