# Ramsay — Strix Halo LLM server (FaEX1). Bare-min phase-1: root HM, SSH, Tailscale, disko btrfs.
#
# Install from GoofyDesky (980 PRO by-id; Desky OS disk untouched):
#   cd ~/NixConfig
#   export AGE_IDENTITY_FILE=$HOME/.ssh/id_ed25519
#   sudo -E nix run github:nix-community/nixos-anywhere -- \
#     --flake '.#Ramsay' \
#     --target-host root@127.0.0.1 \
#     --phases disko,install \
#     --build-on remote
# Skip kexec+reboot: target is localhost — default phases reboot Desky.
#
# Post-install switch from minimal ISO (SSD at /mnt):
#   rsync -av ~/NixConfig/ nixos@<ip>:/tmp/NixConfig/
#   sudo mount --bind /tmp/NixConfig /mnt/root/NixConfig
#   sudo nixos-enter --root /mnt -- bash -lc '
#     cd /root/NixConfig
#     nixos-rebuild switch --flake ".#Ramsay" --install-bootloader
#   '
# Host SSH keys: local generateHostKeys (not agenix).
{
  inputs,
  self,
  withSystem,
  ...
}:
let
  hostname = self.constants.ramsayName;
  # Stable across machines — follows the physical 980 PRO, not a slot name.
  ramsayDisk = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S6B0NL0TB25886K";
in
{
  flake = {
    nixosConfigurations.Ramsay = withSystem "x86_64-linux" (
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
          inherit hostname;
        };
        modules = with self.nixosModules; [
          Ramsay
          RamsayDisko
          RamsayHardware
          self.stylixCommon
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.agenix.nixosModules.default
          self.nixConfig
          caTrust
          tailscale
          gufo
          inference
        ];
      }
    );

    homeConfigurations.Ramsay = {
      imports = with self.homeModules; [
        nixos-home
        atuin
        zoxide
        nushell
        zsh
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

    # Agent coding workspace: pi + tmux orchestrator.
    homeConfigurations.RamsayAgent =
      { lib, pkgs, ... }:
      {
        imports = with self.homeModules; [
          nixos-home
          atuin
          zoxide
          nushell
          zsh
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
          bash
          carapace
          nixconfig-sync
        ];
        tools.nixconfigSync.enable = true;

        # Agent decrypts API secrets with its own age identity.
        age.identityPaths = [ "/run/agenix/agent-ramsay-age-key" ];

        # The pi hook and the tmux status line read these from a fixed path
        # under $HOME, so link the packaged copies instead of a checkout path.
        home.file.".local/share/tmax/agent_status.py".source =
          "${pkgs.tmax}/share/tmax/scripts/agent_status.py";
        home.file.".local/share/tmax/lab_agents.py".source =
          "${pkgs.tmax}/share/tmax/scripts/lab_agents.py";

        # Empty `agents` tmux session on boot — pi started manually after attach.
        systemd.user.services.agents-tmux = {
          Unit = {
            Description = "Empty tmux session 'agents' (pi agent workspace)";
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Panes spawned from this session inherit PATH — must include HM profile
            # bins (starship/zoxide/…) or shells break.
            Environment = "PATH=/home/agent/.nix-profile/bin:/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin:/usr/bin:/bin";
            ExecStart = "${lib.getExe pkgs.tmux} new-session -d -s agents";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };

    nixosModules.Ramsay =
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
        # Agent user's age identity: encrypted private key, decrypted by root at
        # activation, made readable by agent so HM age.identityPaths can use it.
        age.secrets."agent-ramsay-age-key" = {
          file = ../../secrets/agent-ramsay-age-key.age;
          owner = "agent";
          group = "agent";
          mode = "0400";
        };

        # Root-owned: sshd reads the crypt hash, the agent user never does.
        age.secrets."agent-password" = {
          file = ../../secrets/agent-password.age;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        nix.settings.trusted-users = lib.mkAfter [
          "root"
          "goofy"
          "agent"
          "@wheel"
        ];

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

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        networking.hostName = hostname;
        networking.firewall.enable = true;
        networking.networkmanager.enable = true;

        environment.sessionVariables = {
          NH_OS_FLAKE = "/root/NixConfig";
        };
        environment.shells = with pkgs; [
          nushell
          zsh
          bash
        ];
        programs.zsh.enable = true;

        time.timeZone = "Asia/Hong_Kong";
        i18n.defaultLocale = "en_HK.UTF-8";

        security.sudo = {
          enable = true;
          wheelNeedsPassword = false;

          # agent cannot join wheel: wheel is passwordless above, which the agent
          # workspace spec forbids. nh elevates per command, so a PASSWD rule is
          # required instead of allowing "nh" alone.
          extraRules = [
            {
              users = [ "agent" ];
              commands = [
                {
                  command = "ALL";
                  options = [ "PASSWD" ];
                }
              ];
            }
          ];
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
          systemctl-tui
          jq
        ];

        users.users.${username} = {
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
          ];
        };

        # Agent coding workspace user (AFK / phone-driven pi).
        users.users.agent = {
          isNormalUser = true;
          # Second SSH factor. A password alone stays useless without the key.
          hashedPasswordFile = config.age.secrets."agent-password".path;
          extraGroups = [ "networkmanager" ];
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
          ];
        };

        # isNormalUser alone does not create a same-named group, and agenix
        # chowns the agent key to agent:agent.
        users.groups.agent = { };

        # Agent needs key plus password, and only from the tailnet. The Match
        # block sits in extraConfig, which NixOS appends after its own keys.
        # Password auth is off everywhere else, so a LAN or internet source
        # cannot reach the agent password rule at all.
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
          extraConfig = ''
            # 100.105.133.71 is the phone tailnet node. Key only, since tmax
            # unlock asks for the password instead. Replace it when it changes.
            Match User agent Address 100.105.133.71
              PubkeyAuthentication yes
              PasswordAuthentication no
              KbdInteractiveAuthentication no
              AuthenticationMethods publickey
              MaxSessions 64

            Match User agent Address 100.64.0.0/10,fd7a:115c:a1e0::/48
              PubkeyAuthentication yes
              PasswordAuthentication yes
              KbdInteractiveAuthentication no
              AuthenticationMethods publickey,password
              MaxSessions 64
          '';
        };

        # sshd derives the PAM unix rule from the global password setting, which
        # is now false. The Match block above still needs it for the agent.
        security.pam.services.sshd.unixAuth = lib.mkOverride 50 true;

        # mosh UDP 60000-61000 reach the host through tailscale0, which the
        # tailscale module already trusts. No firewall ports are needed.
        programs.mosh.enable = true;

        systemd.services.gufo-models = {
          description = "Fetch pinned inference weights";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # curl --create-dirs honours the umask. The ASR unit runs as a
            # DynamicUser, so a 0750 model dir hides config.json from it.
            UMask = "0022";
          };
          path = [
            pkgs.curl
            pkgs.coreutils
          ];
          environment.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          script = ''
            root=/var/lib/inference/models

            get() {
              if [ -s "$2" ]; then
                return 0
              fi
              curl -fL --retry 3 --create-dirs -o "$2.part" "$1"
              mv "$2.part" "$2"
            }

            qwen27b=https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/4ca720788d1e01f1bff70c033e0d0028fd02e502
            get "$qwen27b/Qwen3.8-27B-UD-Q4_K_XL.gguf" \
              "$root/Qwen3.8-27B-UD-Q4_K_XL.gguf"

            dflash=https://huggingface.co/z-lab/Qwen3.8-27B-DFlash2-GGUF/resolve/2d9571f8ce46e151f61c6499c99dee6079e1d610
            get "$dflash/Qwen3.8-27B-DFlash2-Q4_K_M.gguf" \
              "$root/Qwen3.8-27B-DFlash2-Q4_K_M.gguf"

            # gufo reads token_embd.weight at Q8_0 or better, so the older
            # IQ4_NL requant cannot load. Upstream target is UD-Q4_K_XL.
            flash=https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/38bb39ee97821de2c9009abb7e93950eec396e66
            get "$flash/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf" \
              "$root/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
            for shard in 00001 00002 00003 00004; do
              file="Qwen3.8-Flash-Next-UD-Q4_K_XL-$shard-of-00004.gguf"
              get "$flash/UD-Q4_K_XL/$file" "$root/$file"
            done

            asr=https://huggingface.co/Qwen/Qwen3-ASR-1.7B/resolve/7278e1e70fe206f11671096ffdd38061171dd6e5
            for file in \
              chat_template.json \
              config.json \
              generation_config.json \
              merges.txt \
              model-00001-of-00002.safetensors \
              model-00002-of-00002.safetensors \
              model.safetensors.index.json \
              preprocessor_config.json \
              tokenizer_config.json \
              vocab.json
            do
              get "$asr/$file" "$root/Qwen3-ASR-1.7B/$file"
            done

            chmod -R a+rX "$root"
          '';
        };

        home-manager.users.${username} = self.homeConfigurations.Ramsay;
        home-manager.users.agent = self.homeConfigurations.RamsayAgent;

        # pi is the native Pi-Bolt ELF, which hardcodes the generic
        # /lib64/ld-linux-x86-64.so.2 interpreter that NixOS only provides as a stub.
        # Client TERMs (xterm-ghostty, xterm-kitty, wezterm, …) have no terminfo
        # entry in the system profile, so TUIs fail or degrade on them.
        environment.enableAllTerminfo = true;

        programs.nix-ld.enable = true;

        system.stateVersion = "26.05";
      };

    nixosModules.RamsayDisko =
      { lib, ... }:
      {
        disko.devices = {
          disk.main = {
            type = "disk";
            device = ramsayDisk;
            content = {
              type = "gpt";
              partitions = {
                boot = {
                  name = "RAMSAYBOOT";
                  size = "512M";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [
                      "fmask=0077"
                      "dmask=0077"
                    ];
                  };
                };
                root = {
                  name = "RAMSAYROOT";
                  size = "100%";
                  content = {
                    type = "filesystem";
                    format = "btrfs";
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };

    nixosModules.RamsayHardware =
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
          "nvme"
          "xhci_pci"
          "ahci"
          "usb_storage"
          "sd_mod"
          "atlantic"
          "r8169"
        ];
        boot.initrd.kernelModules = [ ];
        boot.kernelParams = [ "ttm.pages_limit=29400781" ];
        boot.kernelModules = [
          "kvm-amd"
          "atlantic"
          "r8169"
        ];
        boot.extraModulePackages = [ ];

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
  };
}
