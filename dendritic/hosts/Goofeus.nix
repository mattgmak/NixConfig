{
  inputs,
  self,
  withSystem,
  ...
}:
{
  flake = {
    nixosConfigurations.Goofeus = withSystem "x86_64-linux" (
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
          username = "root";
          mv = self'.legacyPackages.mv;
          hostname = self.constants.serverName;
        };
        modules = with self.nixosModules; [
          Goofeus
          GoofeusHardware
          self.stylixCommon
          inputs.home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.agenix.nixosModules.default
          self.nixConfig
          tailscale
          unbound
          pihole
          glance
          arr
          transmissionGluetun
          immich
          copyparty
          donetick
          trek
          radicale
          # nextcloud
          caddy
          resticGoofeus
          syncthing
        ];
      }
    );

    homeConfigurations.Goofeus = {
      imports = with self.homeModules; [
        nixos-home
        atuin
        zoxide
        nushell
        neovim
        starship
        yazi
        git
        delta
        gh
        direnv
        devenv
        lazygit
        btop
        bat
        nix-index-database
      ];
    };

    # Agent coding workspace: pi + tmux orchestrator + handmux phone frontend.
    homeConfigurations.GoofeusAgent =
      { lib, pkgs, ... }:
      {
        imports = with self.homeModules; [
        nixos-home
        atuin
        zoxide
        nushell
        neovim
        starship
        yazi
        git
        delta
        gh
        direnv
        devenv
        lazygit
        btop
        bat
        nix-index-database
        pi-coding-agent
        tmux
        zellij
        worktrunk
        handmux
        bash
        carapace
        nixconfig-sync
      ];
      programs.handmux = {
        enable = true;
        enableServer = true;
        enableAgentPi = true;
        name = "Goofeus";
        tokenFile = "/run/agenix/handmux-token";
      };
      tools.nixconfigSync.enable = true;

      # Auto-install pi extension deps when needed (first switch after clone,
      # or after vendor extension bumps). Non-fatal: failure leaves pi usable,
      # it only means an extension may need manual pi-npm-i.
      home.activation.autoPiNpmI = lib.hm.dag.entryAfter [ "writeBoundary" "ensureNixConfig" ] ''
        stamp="$HOME/.local/state/pi-npm-i.stamp"
        repo="$HOME/NixConfig"
        mkdir -p "$HOME/.local/state"
        if [[ -f "$stamp" ]] && \
           [[ -z "$(find "$repo/vendor" "$repo/dendritic/home-modules/pi-coding-agent/extensions" \
                     -name package.json -newer "$stamp" -print -quit 2>/dev/null)" ]]; then
          exit 0
        fi
        echo "pi-npm-i: installing pi extension deps..."
        if PATH="$HOME/.nix-profile/bin:$PATH" pi-npm-i; then
          touch "$stamp"
        else
          echo "pi-npm-i: failed (non-fatal) — run manually later"
        fi
      '';

      # Agent decrypts API secrets with its own age identity (root uses the
      # ssh host key via nushell's mkIf; agent gets the dedicated key path).
      age.identityPaths = [ "/run/agenix/agent-age-key" ];

      # Empty `agents` tmux session on boot — pi started manually after attach.
      systemd.user.services.agents-tmux = {
        Unit = {
          Description = "Empty tmux session 'agents' (pi agent workspace)";
          After = [ "handmux.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Panes spawned from this session inherit PATH — must include HM profile
          # bins (starship/zoxide/…) or shells break (see handmux pane shell errors).
          # Agent user is fixed (age.identityPaths etc. assume it); login PATH is
          # ~/.nix-profile + /etc/profiles/per-user/agent + system sw.
          Environment = "PATH=/home/agent/.nix-profile/bin:/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin:/usr/bin:/bin";
          ExecStart = "${lib.getExe pkgs.tmux} new-session -d -s agents";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };

    nixosModules.Goofeus =
      {
        config,
        lib,
        pkgs,
        username,
        hostname,
        mv,
        common-overlays,
        common-nixpkgs-config,
        ...
      }:
      {
        age.secrets.nix-builder-key = {
          file = ../../secrets/nix-builder-goofeus.age;
          mode = "0400";
        };

        # Agent user's age identity: encrypted private key (recipients: Goofeus
        # host key + GoofyDeskyRoot), decrypted by root at activation, made
        # readable by agent so home-manager's age.identityPaths can use it.
        age.secrets.agent-age-key = {
          file = ../../secrets/agent-age-key.age;
          owner = "agent";
          group = "agent";
          mode = "0400";
        };

        # Persistent handmux auth token (HANDMUX_TOKEN=… line). Without a pinned
        # token handmux mints a fresh one each start → phone would re-pair on
        # every reboot. Owner=agent so the systemd user unit can env-load it.
        age.secrets.handmux-token = {
          file = ../../secrets/handmux-token.age;
          owner = "agent";
          group = "agent";
          mode = "0400";
        };

        nix.settings = {
          secret-key-files = [ config.age.secrets.nix-builder-key.path ];
          trusted-users = lib.mkAfter [
            "root"
            "goofy"
            "agent"
            "@wheel"
          ];
        };

        nixpkgs.overlays = common-overlays;
        nixpkgs.config = common-nixpkgs-config;

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit
              hostname
              username
              mv
              ;
          };
          backupFileExtension = "hm-backup-1";
        };
        # Use the systemd-boot EFI boot loader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        networking.hostName = hostname;
        networking.firewall.enable = true;

        # Configure network connections interactively with nmcli or nmtui.
        networking.networkmanager.enable = true;

        environment.sessionVariables =
          let
            homeDir = if username == "root" then "/root" else "/home/${username}";
          in
          {
            NH_OS_FLAKE = "${homeDir}/NixConfig";
          };
        environment.shells = with pkgs; [
          nushell
          bash
        ];

        # Set your time zone.
        time.timeZone = "Asia/Hong_Kong";

        # Select internationalisation properties.
        i18n.defaultLocale = "en_HK.UTF-8";

        security.sudo = {
          enable = true;
          wheelNeedsPassword = false;
        };

        environment.systemPackages = with pkgs; [
          fzf
          ripgrep
          zip
          unzip
          nh
          nvd
          nix-output-monitor
          dua
          lazyjournal
          btop
          powertop
          lazydocker
          systemctl-tui
          jq
        ];

        # Define a user account. Don't forget to set a password with ‘passwd’.
        users.users.${username} = {
          shell = pkgs.nushell;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
          ];
        };

        # Agent coding workspace user (AFK / phone-driven pi).
        users.users.agent = {
          isNormalUser = true;
          extraGroups = [ "networkmanager" ];
          shell = pkgs.nushell;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
          ];
        };

        # Primary group for the agent user (agenix chowns agent-age-key to
        # agent:agent; isNormalUser alone does not create a same-named group).
        users.groups.agent = { };

        # Enable the OpenSSH daemon.
        services.openssh.enable = true;

        home-manager.users.${username} = self.homeConfigurations.Goofeus;
        home-manager.users.agent = self.homeConfigurations.GoofeusAgent;

        swapDevices = [
          {
            device = "/swapfile";
            size = 4 * 1024;
          }
        ];
        powerManagement.powertop.enable = true;

        virtualisation.docker.enable = true;
        virtualisation.podman.enable = true;

        services.transmissionGluetun = {
          enable = true;
          serverRegions = "Netherlands";
        };

        system.stateVersion = "26.05";
      };

    # Do not modify this module!  It was generated by ‘nixos-generate-config’
    # and may be overwritten by future invocations.  Please make changes
    # to /etc/nixos/configuration.nix instead.
    nixosModules.GoofeusHardware =
      {
        config,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [
          (modulesPath + "/installer/scan/not-detected.nix")
        ];

        boot.initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ "kvm-intel" ];
        boot.extraModulePackages = [ ];

        fileSystems."/" = {
          device = "/dev/disk/by-label/NIXROOT";
          fsType = "ext4";
        };

        fileSystems."/boot" = {
          device = "/dev/disk/by-label/NIXBOOT";
          fsType = "vfat";
          options = [
            "fmask=0022"
            "dmask=0022"
          ];
        };

        fileSystems."/mnt/2TBSeagateHDD" = {
          device = "/dev/disk/by-label/2TBSeagateHDD";
          fsType = "ext4";
          options = [
            "defaults"
            "users"
            "nofail"
          ];
        };

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

  };
}
