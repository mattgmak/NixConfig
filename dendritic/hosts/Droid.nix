{ self, inputs, ... }:
{
  # Apps: mv.unstable (aarch64-linux). Proot/bootstrap: nix-on-droid release-24.05 + nixpkgs 24.05 (flake nixpkgs-droid).
  # activationPackage eval: --impure (upstream #545 hardcoded proot store paths). Host may need that proot path in store.
  flake.nixOnDroidConfiguration =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Stylix's home-manager integration reads osConfig (see stylix/home-manager-integration.nix).
      # Nix-on-droid does not pass it like NixOS does; without this, HM infers osConfig lazily and hits infinite recursion.
      hmSpecialArgs = {
        inherit (self.constants) username;
        hostname = "Droid";
        osConfig = config;
      };
      # C-; popup sends the kitty keyboard protocol encoding of Ctrl+; (ESC [ 59 ; 5 u).
      termuxProperties = pkgs.writeText "termux.properties" (lib.generators.toKeyValue { } {
        extra-keys = "[['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN','DRAWER',{'key':'KEYBOARD','popup':{'macro':'ESC [ 5 9 ; 5 u','display':'C-;'}}]]";
      });
      # One command into the tmux session "agents" on Ramsay. mosh keeps the
      # link across a network switch; ssh -4 -t is the fallback when mosh is absent.
      # Rename this attribute and the shellAliases entry together.
      ramsay = pkgs.writeShellScriptBin "ramsay" ''
        set -eu
        # Ramsay tailnet IPv4. MagicDNS can answer AAAA on some networks and the
        # v6 path fails there, so every transport forces IPv4. The host key for
        # this address is the same key as ramsay.dab-octatonic.ts.net.
        host="agent@100.76.193.66"
        session="agents"
        opts="-4 -p 22 -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
        case "''${TERM:-}" in
          "" | dumb | unknown) export TERM=xterm-256color ;;
        esac
        if command -v mosh >/dev/null 2>&1; then
          exec mosh --ssh="ssh $opts" "$host" -- tmux new-session -A -s "$session"
        fi
        exec ssh -t $opts "$host" "TERM=xterm-256color tmux new-session -A -s $session"
      '';
    in
    {
      imports = [
        inputs.stylix.nixOnDroidModules.stylix
        # Same palette/fonts as other hosts; stylix requires image or base16Scheme on both droid and HM.
        self.stylixCommon
      ];

      stylix = {
        overlays.enable = lib.mkForce false;
        enable = lib.mkForce true;
      };

      environment.packages = with pkgs; [
        procps
        killall
        diffutils
        findutils
        util-linux
        tzdata
        hostname
        man
        gnugrep
        gnupg
        gnused
        gnutar
        bzip2
        gzip
        xz
        zip
        unzip
        which
        openssh
        mosh
        tmux
        ramsay
        curlMinimal
        busybox
        cursor-cli
        dnsutils
      ];

      home-manager.config = {
        # The name is "ramsay": rename it here and in the wrapper above.
        programs.zsh.shellAliases.ramsay = "${ramsay}/bin/ramsay";
        imports = with self.homeModules; [
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
          carapace
          tmux
          nix-index-database
          # pi-coding-agent off until signed remote builders verified on device
          # pi-coding-agent
        ];
        # Stylix enables gnome/gtk/kde on Linux by default; those use dconf and fail HM activation on Termux (no session dbus).
        stylix.targets.gnome.enable = lib.mkForce false;
        stylix.targets.gtk.enable = lib.mkForce false;
        stylix.targets.kde.enable = lib.mkForce false;
        # HM defaults dconf on for Linux; dbus is not available in this environment.
        dconf.enable = false;
        # agenix's HM module only decrypts from a systemd user service, which does
        # not exist on Android, and it keeps secrets in XDG_RUNTIME_DIR, which
        # Android leaves unset (all reads would hit /agenix). Keep them under
        # $HOME instead; the activation step lives in zsh.nix.
        age.secretsDir = lib.mkForce "\${HOME}/.local/state/agenix";
        age.secretsMountPoint = lib.mkForce "\${HOME}/.local/state/agenix.d";
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
        };
        # Termux extra-keys row: DRAWER plus KEYBOARD (toggles the soft keyboard) on row 2.
        # Swipe up on KEYBOARD sends Ctrl+; as kitty CSI-u bytes. Termux maps Ctrl only to
        # letters and [ ] ^ _ /, so the CTRL modifier alone drops ';' (no legacy encoding).
        # nix-on-droid has no option for termux.properties, so manage it via home.file.
        # The app runs outside proot and reads real files only (store symlinks are invisible
        # there, docs/droid-handbook.md pitfall 9), so termuxRealFiles copies the file.
        home.file.".termux/termux.properties".source = termuxProperties;
        # lib.hm is home-manager's lib; the outer lib here is nixpkgs'. Pass the dag
        # entry attrs directly. hm.dag.isEntry requires data, after, AND before; a
        # missing field makes HM wrap the whole attrs as the entry's data string.
        home.activation.termuxRealFiles = {
          after = [ "writeBoundary" ];
          before = [ ];
          data = ''
          mkdir -p "$HOME/.termux"
          rm -f "$HOME/.termux/termux.properties"
          cp "${termuxProperties}" "$HOME/.termux/termux.properties"
          chmod u+w "$HOME/.termux/termux.properties"
        '';
        };
        # Root-owned store dirs in fpath fail compaudit under the non-root
        # Termux/proot uid and the [y/n] check aborts completions on every
        # new shell; -u skips the audit (nix store is still read-only).
        programs.zsh.completionInit = "autoload -U compinit && compinit -u";
        home = {
          stateVersion = "24.05";
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = hmSpecialArgs;
        backupFileExtension = "hm-backup-1";
      };

      # user.userName = self.constants.username;
      # user.shell = "${pkgs.nushell}/bin/nu";
      user.shell = "${pkgs.zsh}/bin/zsh";

      # Backup etc files instead of failing to activate generation if a file already exists in /etc
      environment.etcBackupExtension = ".bak";

      # Read the changelog before changing this value
      system.stateVersion = "24.05";

      # Flakes only. Remote builders (ssh-ng) break HM profile activation on Termux:
      # "getting pseudoterminal attributes: Permission denied" building user-environment.
      # Re-enable builders after ssh-ng verified from nix-on-droid proot env.
      nix.extraOptions = ''
        experimental-features = nix-command flakes
      '';
      nix = {
        substituters = [
          "https://cache.nixos.org"
          "https://nix-on-droid.cachix.org"
          "https://nix-community.cachix.org"
          "https://yazi.cachix.org"
        ];
        trustedPublicKeys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        ]
        ++ self.builderPublicKeys;
      };

      # ${pkgs.nerd-fonts.iosevka-term} available at eval time via mv overlay; types.path, activated as ~/.termux/font.ttf.
      terminal.font = lib.mkForce "${pkgs.nerd-fonts.iosevka-term}/share/fonts/truetype/NerdFonts/IosevkaTerm/IosevkaTermNerdFont-Regular.ttf";
      # Set your time zone
      time.timeZone = "Asia/Hong_Kong";
    };
}
