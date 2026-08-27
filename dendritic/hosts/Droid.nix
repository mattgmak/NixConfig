{ self, inputs, ... }:
{
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
        curlMinimal
        busybox
        cursor-cli
        dnsutils
      ];

      home-manager.config = {
        imports = with self.homeModules; [
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
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
        };
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
      user.shell = "${pkgs.bash}/bin/bash";

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
          "https://nix-community.cachix.org"
          "https://yazi.cachix.org"
        ];
        trustedPublicKeys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        ]
        ++ self.builderPublicKeys;
      };

      # terminal.font is set by stylix/droid/fonts.nix from stylix.fonts.monospace (see stylixCommon).
      # Set your time zone
      time.timeZone = "Asia/Hong_Kong";
    };
}
