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
          strixHaloMemory
          hermes
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
        bash
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
      let
        halogenSignalPack = "/var/lib/inference/models/halogen-signal";
        halogenAbliterPack = "/var/lib/inference/models/halogen-abliter-v2";

        # The two stacks differ in four values only. The rest is the tuning set
        # the bench ran with success.
        halogenContainer =
          {
            enginePort,
            apiPort,
            modelId,
            checkpoint,
            packDir,
          }:
          {
            image = "ghcr.io/peonist-ai/halogen-flash-server:0.18.22";
            # Host networking shares the host stack, so the API answers the
            # tailnet. The engine keeps its loopback bind, because the engine
            # protocol has no authentication.
            networks = [ "host" ];
            devices = [
              "/dev/kfd"
              "/dev/dri"
            ];
            volumes = [ "${packDir}:/models:ro" ];
            extraOptions = [
              "--group-add=keep-groups"
              "--ipc=host"
              "--ulimit=memlock=-1:-1"
            ];
            environment = {
              HALOGEN_PORT = toString enginePort;
              HALOGEN_API_PORT = toString apiPort;
              HALOGEN_MODEL_ID = modelId;
              HALOGEN_CHECKPOINT = checkpoint;
              HALOGEN_NGRAM_TABLE = "/models/qwen38-flash-next-ngram.hgn";
              HALOGEN_VISION_TOWER = "1";
              HALOGEN_CTX = "131072";
              HALOGEN_MAX_TOK = "16384";
              HALOGEN_KV_SLOTS = "4";
              HALOGEN_KV_POOL_POSITIONS = "262144";
              HALOGEN_PROMPT_CACHE = "2";
              HALOGEN_COMPOSABLE_CONTEXT = "1";
              # Parent plus forked subagents: keeps the parent's resume point
              # when two children store theirs. Raises the entry count to 32.
              HALOGEN_CACHE_BRANCHES = "3";
              # Stops the kernel reclaiming weight pages for ngram rows, which
              # makes the driver remove and restore the engine mapping.
              HALOGEN_WEIGHTS_LOCK = "1";
            };
          };
      in
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
        # nixpkgs defaults this to `ls -alh` in /etc/zshrc and /etc/bashrc, and an
        # alias shadows the lazygit shell function of the same name.
        environment.shellAliases.l = null;
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
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
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
          # CPU + APU + Strix Halo XDNA NPU TUI: btop has no NPU panel.
          amdtop
        ];

        users.users.${username} = {
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
            MacMini
          ];
        };

        # Agent coding workspace user (AFK / phone-driven pi).
        users.users.agent = {
          isNormalUser = true;
          # Home Manager user activation needs a live user manager. Without linger,
          # user@1000 dies on logout and /run/user/1000/bus goes stale.
          linger = true;
          # Second SSH factor. A password alone stays useless without the key.
          hashedPasswordFile = config.age.secrets."agent-password".path;
          extraGroups = [ "networkmanager" ];
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = with self.sshKeys; [
            GoofyDesky
            GoofyEnvy
            Droid
            MacMini
          ];
        };

        # isNormalUser alone does not create a same-named group, and agenix
        # chowns the agent key to agent:agent.
        users.groups.agent = { };

        # Key only across the tailnet. The Match block sits in extraConfig,
        # which NixOS appends after its own keys.
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
          extraConfig = ''
            Match User agent Address 100.64.0.0/10,fd7a:115c:a1e0::/48
              PubkeyAuthentication yes
              PasswordAuthentication no
              KbdInteractiveAuthentication no
              AuthenticationMethods publickey
              MaxSessions 64
          '';
        };

        # mosh UDP 60000-61000 reach the host through tailscale0, which the
        # tailscale module already trusts. No firewall ports are needed.
        programs.mosh.enable = true;

        # The kernel keeps RAPL counters root-only (CVE-2020-8694), so btop cannot
        # read CPU package watts. udev MODE only touches device nodes, never sysfs
        # attribute files, so chmod the attribute through RUN.
        services.udev.extraRules = lib.mkAfter ''
          ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", TEST=="energy_uj", RUN+="${pkgs.coreutils}/bin/chmod 0444 /sys/%p/energy_uj"
        '';

        systemd.services.gufo-models = {
          description = "Fetch pinned inference weights";
          wantedBy = [ "inference.target" ];
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
            set -eu
            export LC_ALL=C
            root=/var/lib/inference/models
            manifest=$(mktemp)
            keep=$(mktemp)
            found=$(mktemp)

            # Each manifest line is "url dest". One curl per 45 GiB shard runs at
            # about 77 MB/s, so the serial form cost 41 minutes for the Swift set.
            # The keep list drives the prune at the end.
            want() {
              printf '%s %s\n' "$1" "$2" >> "$manifest"
              printf '%s\n' "$2" >> "$keep"
            }

            fetch() {
              [ -s "$2" ] && exit 0
              curl -fL --retry 3 --retry-all-errors --create-dirs -o "$2.part" "$1"
              mv "$2.part" "$2"
            }
            export -f fetch

            # gufo reads token_embd.weight at Q8_0 or better, so the older
            # IQ4_NL requant cannot load. Upstream target is UD-Q4_K_XL.
            flash=https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/38bb39ee97821de2c9009abb7e93950eec396e66
            want "$flash/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf" \
              "$root/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
            want "$flash/mmproj-BF16.gguf" "$root/mmproj-BF16.gguf"
            for shard in 00001 00002 00003 00004; do
              file="Qwen3.8-Flash-Next-UD-Q4_K_XL-$shard-of-00004.gguf"
              want "$flash/UD-Q4_K_XL/$file" "$root/$file"
            done

            # Swift 1.5 publishes no UD-Q4_K_XL build, so these Q8_0 shards feed
            # gufo-swift-requant. The projector takes its own dir because gufo
            # resolves a sibling by base name. The requant deletes the shards,
            # so gate them on its output: an ungated loop re-downloads 175 GiB
            # at every boot.
            swift=https://huggingface.co/ukisai/Swift-1.5-Qwen3.8-Flash-Next-GGUF/resolve/0142554c963a8653912c0c8283f05f13f63653f3
            if [ ! -s "$root/swift/Swift-1.5-Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00005.gguf" ]; then
              for shard in 00001 00002 00003 00004 00005; do
                file="Swift-1.5-Qwen3.8-Flash-Next-Q8_0-$shard-of-00005.gguf"
                want "$swift/Q8_0/$file" "$root/swift/$file"
              done
            fi
            want "$swift/mmproj-Swift-1.5-Qwen3.8-Flash-Next-BF16.gguf" \
              "$root/swift/mmproj-BF16.gguf"

            imatrix=https://huggingface.co/ukisai/Swift-1.5-Qwen3.8-Flash-Next-GSQ-RCO-GGUF/resolve/99bb8f7f95c7aa7b24a36a7786a4f657b30f5d3d
            want "$imatrix/imatrix-swiftfn-v1mix.gguf" \
              "$root/swift/imatrix-swiftfn-v1mix.gguf"

            # This projector shares its base name with the stock one. Gufo picks
            # the wrong sibling for the parent dir, so the subdir stays separate.
            uncensored=https://huggingface.co/vmlinux/Qwen3.8-Flash-Next-Uncensored-Gufo-Q4Mix-GGUF/resolve/0a0843cce72b4d8c377096960b3f0f9c0f4d197f
            want "$uncensored/mmproj-BF16.gguf" "$root/uncensored/mmproj-BF16.gguf"
            want "$uncensored/Qwen3.8-Flash-Next-Uncensored-Gufo-Q4Mix.gguf" \
              "$root/uncensored/Qwen3.8-Flash-Next-Uncensored-Gufo-Q4Mix.gguf"
            mtp=https://huggingface.co/jcbtc/Qwen3.8-Flash-CIRU-STRIX-Orca/resolve/139c9f5eb561dafbcf7cfab0622661b6fc0137e7
            want "$mtp/mtp/Qwen3.8-Flash-CIRU-STRIX-Orca-MTP-Q8_0.gguf" \
              "$root/uncensored/Qwen3.8-Flash-CIRU-STRIX-Orca-MTP-Q8_0.gguf"

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
              want "$asr/$file" "$root/Qwen3-ASR-1.7B/$file"
            done

            # Halogen packs. The engine needs tokenizer.json in tokenizer/ beside
            # the checkpoint, and the Signal repo ships only three tokenizer
            # files, so tokenizer.json and the merges come from peonist-ai.
            signal=https://huggingface.co/Quat3rnion/Signal-3.8-Flash-Next-HGN-v2-abliterated/resolve/d293172ad15cefcad27d4cfda829f2d2e02f3fda
            for file in \
              model.hgn \
              qwen38-flash-next-ngram.hgn \
              qwen38-flash-next-vision.hgn \
              config.json \
              preprocessor_config.json \
              video_preprocessor_config.json
            do
              want "$signal/$file" "$root/halogen-signal/$file"
            done
            for file in chat_template.jinja config.json tokenizer_config.json; do
              want "$signal/tokenizer/$file" "$root/halogen-signal/tokenizer/$file"
            done

            tok=https://huggingface.co/peonist-ai/halogen-qwen3.8-flash-next/resolve/e053f488b120b99ed2525e6ac99f68c51b3b6179
            for file in generation_config.json merges.txt tokenizer.json vocab.json; do
              want "$tok/tokenizer/$file" "$root/halogen-signal/tokenizer/$file"
            done

            # The v2 repo ships one .hgn and no lookup table, no image sidecar
            # and no tokenizer. Both stacks run with the vision tower on, so the
            # v2 dir takes the same shared files.
            v2=https://huggingface.co/Quat3rnion/halogen-qwen3.8-flash-next-v2-abliterated/resolve/2fd96054e10fd12ac5d667a5be897fd58ab6b6ad
            want "$v2/qwen38-flash-next-v2-abliterated.hgn" \
              "$root/halogen-abliter-v2/qwen38-flash-next-v2-abliterated.hgn"
            want "$signal/qwen38-flash-next-ngram.hgn" \
              "$root/halogen-abliter-v2/qwen38-flash-next-ngram.hgn"
            want "$signal/qwen38-flash-next-vision.hgn" \
              "$root/halogen-abliter-v2/qwen38-flash-next-vision.hgn"
            for file in \
              chat_template.jinja \
              generation_config.json \
              merges.txt \
              tokenizer.json \
              tokenizer_config.json \
              vocab.json
            do
              want "$tok/tokenizer/$file" "$root/halogen-abliter-v2/tokenizer/$file"
            done

            # The requant writes this map and its guard path never rebuilds it, so
            # the prune must not treat it as litter.
            printf '%s\n' "$root/swift/tensor-types.txt" >> "$keep"

            # The requant unit produces these five files. This fetch never
            # downloads them and gufo loads them, so the prune needs their names.
            for shard in 00001 00002 00003 00004 00005; do
              printf '%s\n' \
                "$root/swift/Swift-1.5-Qwen3.8-Flash-Next-UD-Q4_K_XL-$shard-of-00005.gguf" >> "$keep"
            done

            # The bench trees live on this filesystem and hold the same bytes, so
            # a hardlink costs no space and no download. A dest that exists wins,
            # and the bench file is only read as the link target.
            seed() {
              if [ -f "$1" ] && [ ! -e "$2" ]; then
                mkdir -p "$(dirname "$2")"
                ln -f "$1" "$2" 2>/dev/null || true
              fi
            }
            bench=/home/agent/bench-models/halogen-packs
            while read -r src dest; do
              seed "$bench/$src" "$root/$dest"
            done <<'SEED'
signal/model.hgn halogen-signal/model.hgn
signal/qwen38-flash-next-ngram.hgn halogen-signal/qwen38-flash-next-ngram.hgn
signal/qwen38-flash-next-vision.hgn halogen-signal/qwen38-flash-next-vision.hgn
signal/config.json halogen-signal/config.json
signal/preprocessor_config.json halogen-signal/preprocessor_config.json
signal/video_preprocessor_config.json halogen-signal/video_preprocessor_config.json
signal/tokenizer/chat_template.jinja halogen-signal/tokenizer/chat_template.jinja
signal/tokenizer/config.json halogen-signal/tokenizer/config.json
signal/tokenizer/generation_config.json halogen-signal/tokenizer/generation_config.json
signal/tokenizer/merges.txt halogen-signal/tokenizer/merges.txt
signal/tokenizer/tokenizer_config.json halogen-signal/tokenizer/tokenizer_config.json
signal/tokenizer/tokenizer.json halogen-signal/tokenizer/tokenizer.json
signal/tokenizer/vocab.json halogen-signal/tokenizer/vocab.json
abliter-v2/qwen38-flash-next-v2-abliterated.hgn halogen-abliter-v2/qwen38-flash-next-v2-abliterated.hgn
abliter-v2/qwen38-flash-next-ngram.hgn halogen-abliter-v2/qwen38-flash-next-ngram.hgn
signal/qwen38-flash-next-vision.hgn halogen-abliter-v2/qwen38-flash-next-vision.hgn
abliter-v2/tokenizer/chat_template.jinja halogen-abliter-v2/tokenizer/chat_template.jinja
abliter-v2/tokenizer/generation_config.json halogen-abliter-v2/tokenizer/generation_config.json
abliter-v2/tokenizer/merges.txt halogen-abliter-v2/tokenizer/merges.txt
abliter-v2/tokenizer/tokenizer_config.json halogen-abliter-v2/tokenizer/tokenizer_config.json
abliter-v2/tokenizer/tokenizer.json halogen-abliter-v2/tokenizer/tokenizer.json
abliter-v2/tokenizer/vocab.json halogen-abliter-v2/tokenizer/vocab.json
SEED

            # Name bash by store path. A unit PATH carries coreutils, findutils,
            # grep, sed and systemd, but not bash.
            xargs -a "$manifest" -P 4 -n 2 ${pkgs.bash}/bin/bash -c 'fetch "$0" "$1"'

            # Drop files this unit does not name. A pinned URL change leaves the
            # old build behind, and a 45 GiB shard is hard to find by hand. The
            # Q8_0 set leaves the list once the requant output exists, so this
            # reclaims 175 GiB.
            sort "$keep" > "$keep.sorted"
            if [ "$(wc -l < "$keep.sorted")" -lt 20 ]; then
              echo "keep list holds fewer than 20 files, skip prune" >&2
              exit 1
            fi
            find "$root" -type f | sort > "$found"
            comm -13 "$keep.sorted" "$found" | while read -r f; do
              echo "prune $f"
              rm -f "$f"
            done
            find "$root" -mindepth 1 -type d -empty -delete
            rm -f "$manifest" "$keep" "$keep.sorted" "$found"

            chmod -R a+rX "$root"
          '';
        };

        # gufo loads one Flash-Next tensor map only, so Swift 1.5 needs a requant
        # of its Q8_0 source to the types of the stock build.
        systemd.services.gufo-swift-requant = {
          description = "Requantize Swift 1.5 for gufo";
          wantedBy = [ "inference.target" ];
          after = [ "gufo-models.service" ];
          requires = [ "gufo-models.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Nice = 15;
            IOSchedulingClass = "idle";
          };
          path = [
            pkgs.coreutils
            pkgs.llama-cpp
            (pkgs.python3.withPackages (ps: [ ps.gguf ]))
          ];
          script = ''
            set -eu
            root=/var/lib/inference/models
            swift=$root/swift
            out=$swift/Swift-1.5-Qwen3.8-Flash-Next-UD-Q4_K_XL

            # gufo loads the requant output. The Q8_0 sources cost 175 GiB and
            # feed nothing after this point.
            cleanup() {
              rm -f "$swift"/Swift-1.5-Qwen3.8-Flash-Next-Q8_0-*-of-00005.gguf
            }

            # The guard exits before the quantize step, so cleanup has to run on
            # both paths.
            if [ -s "$out-00001-of-00005.gguf" ]; then
              cleanup
              exit 0
            fi

            # The map comes from the stock build, so the result stays identical to
            # what gufo loads today. The name check stops a mismatch before 103 GiB
            # are written.
            python3 ${../../scripts/gguf-tensor-types.py} \
              "$root"/Qwen3.8-Flash-Next-UD-Q4_K_XL-*-of-00004.gguf \
              -- "$swift"/Swift-1.5-Qwen3.8-Flash-Next-Q8_0-*-of-00005.gguf \
              > "$swift/tensor-types.txt"

            # This build takes the output path as the second positional argument.
            llama-quantize \
              --imatrix "$swift/imatrix-swiftfn-v1mix.gguf" \
              --allow-requantize \
              --keep-split \
              --tensor-type-file "$swift/tensor-types.txt" \
              "$swift/Swift-1.5-Qwen3.8-Flash-Next-Q8_0-00001-of-00005.gguf" \
              "$out.gguf" \
              Q4_K_M

            cleanup

            chmod -R a+rX "$root"
          '';
        };

        # One Halogen stack runs at a time: each maps a whole pack into graphics
        # memory, so a second start would evict the first anyway. Signal is the
        # resident main model, abliter-v2 waits for an explicit start.
        virtualisation.oci-containers = {
          backend = "podman";
          containers = {
            halogen-signal = halogenContainer {
              enginePort = 8730;
              apiPort = 8731;
              modelId = "halogen-flash-next-signal-abliterated";
              checkpoint = "/models/model.hgn";
              packDir = halogenSignalPack;
            };
            halogen-abliter-v2 = halogenContainer {
              enginePort = 8740;
              apiPort = 8741;
              modelId = "halogen-flash-next-v2-abliterated";
              checkpoint = "/models/qwen38-flash-next-v2-abliterated.hgn";
              packDir = halogenAbliterPack;
            } // {
              autoStart = false;
            };
          };
        };

        systemd.services.podman-halogen-signal = {
          wantedBy = lib.mkForce [ "inference.target" ];
          after = [ "gufo-models.service" ];
          wants = [ "gufo-models.service" ];
          conflicts = [ "podman-halogen-abliter-v2.service" ];
        };

        systemd.services.podman-halogen-abliter-v2 = {
          after = [ "gufo-models.service" ];
          wants = [ "gufo-models.service" ];
          conflicts = [ "podman-halogen-signal.service" ];
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
        # GTT caps the RAM the GPU may map. 29400781 pages = 112.15 GiB of
        # 124.9 GiB, which left 12.75 GiB for the kernel and all userspace. The
        # 2026-10-30 hang peaked at 95.5 GiB mapped, so 108 GiB keeps the
        # resident model and widens the host buffer to 16.9 GiB.
        boot.kernelParams = [
          "ttm.pages_limit=28311552"
          # Passthrough domain keeps device translation for the NPU driver
          # while dropping the per-map IOMMU work on the GPU path.
          "iommu=pt"
        ];
        # Locked weight pages cannot move, so skip compaction.
        boot.kernel.sysctl."vm.compact_unevictable_allowed" = 0;
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
