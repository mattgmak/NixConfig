{
  inputs,
  self,
  withSystem,
  ...
}:
{
  flake = {
    nixosConfigurations.GoofyEnvy = withSystem "x86_64-linux" (
      {
        config,
        inputs',
        ...
      }:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs inputs';
          inherit (self.constants) username;
          inherit (config) packages common-overlays common-nixpkgs-config;
          hostname = self.constants.laptopName;
        };
        modules = with self.nixosModules; [
          common
          caTrust
          GoofyEnvy
          GoofyEnvyHardware
          steam
          tailscale
          inputs.agenix.nixosModules.default
        ];
      }
    );

    homeConfigurations.GoofyEnvy = { pkgs, ... }: {
      imports = with self.homeModules; [
        nixos-home
        atuin
        zoxide
        zen-browser
        nushell
        zsh
        wezterm
        neovim
        starship
        yazi
        git
        delta
        gh
        direnv
        devenv
        lazygit
        ghostty
        pi-coding-agent
        carapace
        bluetui
        hyprland
        hyprgrass
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
        worktrunk
        gh-dash
        btop
        bat
        nix-index-database
        tailscale-systray
        voxtype
        bash
      ];
      # whisper-dictation defines no enable option. Dropping it from the
      # imports list is the disable path.
      voxtype = {
        enable = true;
        asrBaseUrl = "https://asr.dab-octatonic.ts.net";
      };

      # pi-clip server: ssh -R localhost:7779 lands here and gets one PNG back. With
      # Accept set, systemd runs the template named after the socket once per
      # connection and passes that connection in as fd 3. ExecStart needs bash for
      # the >&3 redirect, and it picks the live Wayland socket by newest mtime
      # because the user manager starts before Hyprland exports WAYLAND_DISPLAY.
      systemd.user.sockets.pi-clip-serve = {
        Unit.Description = "pi-clip clipboard server socket";
        Socket.ListenStream = "127.0.0.1:7779";
        Socket.Accept = true;
        Install.WantedBy = [ "sockets.target" ];
      };

      systemd.user.services."pi-clip-serve@" = {
        Unit.Description = "pi-clip clipboard server for one connection";
        Service.ExecStart = "${pkgs.bash}/bin/bash -c 'export WAYLAND_DISPLAY=$(cd /run/user/$UID && ls -1t | grep -m1 ^wayland-) && exec ${pkgs.wl-clipboard}/bin/wl-paste -t image/png >&3'";
        Service.Type = "oneshot";
      };
    };

    nixosModules.GoofyEnvy =
      {
        pkgs,
        lib,
        username,
        common-overlays,
        common-nixpkgs-config,
        ...
      }:
      {
        nixpkgs.overlays = common-overlays;
        nixpkgs.config = common-nixpkgs-config;

        nix = {
          distributedBuilds = true;
          buildMachines = [
            (self.mkBuilder self.builderSites.ramsay {
              sshKey = "/home/${username}/.ssh/id_ed25519";
            })
          ];
        };

        # Bootloader
        imports = [
          self.nixosModules.inputRemapper
          inputs.xremap-flake.nixosModules.default
        ];

        home-manager.users.${username} = self.homeConfigurations.GoofyEnvy;

        # common.nix sets no keys here. Ramsay's agent key is listed so
        # tmux-bridge can ssh back and run xdg-open or wl-copy.
        users.users.${username}.openssh.authorizedKeys.keys = with self.sshKeys; [
          Ramsay
          RamsayAgentSsh
        ];

        # The FQDN joins the pattern because ssh applies a Host block only when its
        # pattern matches the name typed on the command line. common.nix already
        # sets extraConfig, so append with mkAfter.
        programs.ssh.extraConfig = lib.mkAfter ''
          Host ramsay ramsay.dab-octatonic.ts.net
            User agent
            ControlMaster auto
            ControlPath ~/.ssh/cm-%r@%h:%p
            ControlPersist yes
            ServerAliveInterval 30
            RemoteForward /home/agent/.pi-clip/envy.sock localhost:7779
            SetEnv LC_PI_CLIP=envy
        '';

        environment.systemPackages = with pkgs; [
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
        };

        services.xremap = {
          userName = username;
          withHypr = true;
          # Map CapsLock to Escape
          yamlConfig = ''
            modmap:
              # - name: "CapsLock"
              #   remap:
              #     CapsLock: esc
              - name: "CapsLock Special Layer"
                remap:
                  CapsLock:
                    skip_key_event: true
                    press: { set_mode: caps_layer }
                    release: { set_mode: default }
            keymap:
              - name: "Caps Lock Special Layer Mappings"
                mode: caps_layer
                remap:
                  h: left
                  j: down
                  k: up
                  l: right
                  n: home
                  m: pagedown
                  comma: pageup
                  dot: end
                  g: esc
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

        hardware.graphics = {
          enable = true;
          package = pkgs.mesaForHyprland;
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

        system.stateVersion = "24.11";
      };

    # Do not modify this module!  It was generated by ‘nixos-generate-config’
    # and may be overwritten by future invocations.  Please make changes
    # to /etc/nixos/configuration.nix instead.
    nixosModules.GoofyEnvyHardware =
      {
        config,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

        boot.initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "sd_mod"
          "rtsx_pci_sdmmc"
        ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ "kvm-amd" ];
        boot.extraModulePackages = [ ];

        fileSystems."/" = {
          device = "/dev/disk/by-uuid/20cc20dd-3f6d-493c-bf10-ea258033d04d";
          fsType = "ext4";
        };

        fileSystems."/boot" = {
          device = "/dev/disk/by-uuid/CB08-1C0D";
          fsType = "vfat";
          options = [
            "fmask=0022"
            "dmask=0022"
          ];
        };

        swapDevices = [ ];

        # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
        # (the default) this is the recommended approach. When using systemd-networkd it's
        # still possible to use this option, but it's recommended to use it in conjunction
        # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
        networking.useDHCP = lib.mkDefault true;
        # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

  };
}
